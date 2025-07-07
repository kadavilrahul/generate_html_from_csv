#!/bin/bash

# Chatbot Session Inspector
# Inspects the SQLite database containing chatbot sessions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$SCRIPT_DIR/tmp/data.db"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo -e "${CYAN}🔍 $1${NC}"
}

# Check if database exists
check_database() {
    if [[ ! -f "$DB_FILE" ]]; then
        log_error "Database file not found: $DB_FILE"
        echo ""
        echo "The chatbot session database doesn't exist yet."
        echo "This is normal if the chatbot hasn't been used."
        echo ""
        exit 1
    fi
    
    log_success "Database found: $DB_FILE"
    local size=$(du -h "$DB_FILE" | cut -f1)
    log_info "Database size: $size"
}

# Show database schema
show_schema() {
    log_header "DATABASE SCHEMA"
    echo "=================="
    
    python3 -c "
import sqlite3
conn = sqlite3.connect('$DB_FILE')
cursor = conn.cursor()
cursor.execute(\"SELECT sql FROM sqlite_master WHERE type='table';\")
schemas = cursor.fetchall()
for schema in schemas:
    print(schema[0])
    print()
conn.close()
"
}

# Show session statistics
show_statistics() {
    log_header "SESSION STATISTICS"
    echo "==================="
    
    python3 -c "
import sqlite3
import json
from datetime import datetime

conn = sqlite3.connect('$DB_FILE')
cursor = conn.cursor()

# Total sessions
cursor.execute('SELECT COUNT(*) FROM agent_sessions;')
total = cursor.fetchone()[0]
print(f'📊 Total Sessions: {total}')

if total > 0:
    # Date range
    cursor.execute('SELECT MIN(created_at), MAX(created_at) FROM agent_sessions;')
    min_time, max_time = cursor.fetchone()
    if min_time and max_time:
        min_date = datetime.fromtimestamp(min_time).strftime('%Y-%m-%d %H:%M:%S')
        max_date = datetime.fromtimestamp(max_time).strftime('%Y-%m-%d %H:%M:%S')
        print(f'📅 Date Range: {min_date} to {max_date}')
    
    # Sessions with users
    cursor.execute('SELECT COUNT(*) FROM agent_sessions WHERE user_id IS NOT NULL;')
    with_users = cursor.fetchone()[0]
    print(f'👤 Sessions with User ID: {with_users}')
    print(f'👥 Anonymous Sessions: {total - with_users}')
    
    # Recent activity
    cursor.execute('SELECT COUNT(*) FROM agent_sessions WHERE updated_at > (strftime(\"%s\", \"now\") - 86400);')
    recent = cursor.fetchone()[0]
    print(f'🕐 Active in last 24h: {recent}')

conn.close()
"
}

# Show session list
show_sessions() {
    log_header "SESSION LIST"
    echo "============="
    
    python3 -c "
import sqlite3
import json
from datetime import datetime

conn = sqlite3.connect('$DB_FILE')
cursor = conn.cursor()

cursor.execute('SELECT session_id, user_id, created_at, updated_at, agent_id FROM agent_sessions ORDER BY updated_at DESC;')
sessions = cursor.fetchall()

if not sessions:
    print('No sessions found.')
else:
    for i, session in enumerate(sessions, 1):
        session_id, user_id, created_at, updated_at, agent_id = session
        
        created = datetime.fromtimestamp(created_at).strftime('%Y-%m-%d %H:%M:%S') if created_at else 'Unknown'
        updated = datetime.fromtimestamp(updated_at).strftime('%Y-%m-%d %H:%M:%S') if updated_at else 'Unknown'
        
        print(f'Session {i}:')
        print(f'  🆔 ID: {session_id}')
        print(f'  👤 User: {user_id or \"Anonymous\"}')
        print(f'  🤖 Agent: {agent_id or \"Default\"}')
        print(f'  📅 Created: {created}')
        print(f'  🔄 Updated: {updated}')
        print()

conn.close()
"
}

# Show session details
show_session_details() {
    local session_id=$1
    
    if [[ -z "$session_id" ]]; then
        log_error "Session ID required"
        echo "Usage: $0 --session <session_id>"
        return 1
    fi
    
    log_header "SESSION DETAILS: $session_id"
    echo "================================="
    
    python3 -c "
import sqlite3
import json
from datetime import datetime

conn = sqlite3.connect('$DB_FILE')
cursor = conn.cursor()

cursor.execute('SELECT * FROM agent_sessions WHERE session_id = ?;', ('$session_id',))
session = cursor.fetchone()

if not session:
    print('❌ Session not found')
else:
    columns = [desc[0] for desc in cursor.description]
    session_dict = dict(zip(columns, session))
    
    print(f'🆔 Session ID: {session_dict[\"session_id\"]}')
    print(f'👤 User ID: {session_dict[\"user_id\"] or \"Anonymous\"}')
    print(f'🤖 Agent ID: {session_dict[\"agent_id\"] or \"Default\"}')
    
    if session_dict['created_at']:
        created = datetime.fromtimestamp(session_dict['created_at']).strftime('%Y-%m-%d %H:%M:%S')
        print(f'📅 Created: {created}')
    
    if session_dict['updated_at']:
        updated = datetime.fromtimestamp(session_dict['updated_at']).strftime('%Y-%m-%d %H:%M:%S')
        print(f'🔄 Updated: {updated}')
    
    print()
    
    # Memory data
    if session_dict['memory']:
        try:
            memory = json.loads(session_dict['memory'])
            print('🧠 Memory Data:')
            print(json.dumps(memory, indent=2)[:500] + ('...' if len(str(memory)) > 500 else ''))
            print()
        except:
            print('🧠 Memory Data: (Invalid JSON)')
    
    # Session data
    if session_dict['session_data']:
        try:
            session_data = json.loads(session_dict['session_data'])
            print('📊 Session Data:')
            print(json.dumps(session_data, indent=2)[:500] + ('...' if len(str(session_data)) > 500 else ''))
            print()
        except:
            print('📊 Session Data: (Invalid JSON)')

conn.close()
"
}

# Clean sessions
clean_sessions() {
    log_warning "This will delete ALL chatbot session data!"
    echo ""
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        if [[ -f "$DB_FILE" ]]; then
            rm -f "$DB_FILE"
            log_success "Session database deleted"
        fi
        
        if [[ -d "$SCRIPT_DIR/tmp" ]]; then
            rm -rf "$SCRIPT_DIR/tmp"
            log_success "tmp directory removed"
        fi
        
        log_success "All session data cleaned"
    else
        log_info "Cleanup cancelled"
    fi
}

# Show help
show_help() {
    echo "Chatbot Session Inspector"
    echo "========================="
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  (no args)           Show overview (schema + statistics + sessions)"
    echo "  --schema            Show database schema"
    echo "  --stats             Show session statistics"
    echo "  --sessions          Show session list"
    echo "  --session <id>      Show details for specific session"
    echo "  --clean             Delete all session data"
    echo "  --help, -h          Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Show overview"
    echo "  $0 --session f86ff44d-234a-4e71-8    # Show session details"
    echo "  $0 --clean                           # Clean all sessions"
}

# Main function
main() {
    echo "🤖 Chatbot Session Inspector"
    echo "============================="
    echo ""
    
    case "${1:-}" in
        --schema)
            check_database
            show_schema
            ;;
        --stats)
            check_database
            show_statistics
            ;;
        --sessions)
            check_database
            show_sessions
            ;;
        --session)
            check_database
            show_session_details "$2"
            ;;
        --clean)
            clean_sessions
            ;;
        --help|-h)
            show_help
            ;;
        "")
            # Default: show overview
            check_database
            echo ""
            show_schema
            echo ""
            show_statistics
            echo ""
            show_sessions
            ;;
        *)
            log_error "Unknown option: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"