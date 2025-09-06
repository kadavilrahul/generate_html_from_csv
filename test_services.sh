#!/bin/bash

# Test Services Script
# Tests Gemini API and Database connectivity using shell commands only

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/ecommerce_chatbot/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Load environment variables from .env file
load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error ".env file not found: $ENV_FILE"
        return 1
    fi
    
    log_info "Loading environment from: $ENV_FILE"
    
    # Export variables from .env file
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ $line =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        # Extract key=value pairs
        if [[ $line =~ ^([^=]+)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            
            # Remove quotes if present and trim whitespace
            value=$(echo "$value" | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/" | xargs)
            
            export "$key"="$value"
        fi
    done < "$ENV_FILE"
    
    log_success "Environment variables loaded"
    
    # Show loaded values for verification
    log_info "Loaded configuration:"
    log_info "  DB_HOST: ${DB_HOST:-not set}"
    log_info "  DB_PORT: ${DB_PORT:-not set}"
    log_info "  DB_NAME: ${DB_NAME:-not set}"
    log_info "  DB_USER: ${DB_USER:-not set}"
    if [[ -n "$PG_DB_HOST" ]]; then
        log_info "  PG_DB_HOST: ${PG_DB_HOST:-not set}"
        log_info "  PG_DB_PORT: ${PG_DB_PORT:-not set}"
        log_info "  PG_DB_NAME: ${PG_DB_NAME:-not set}"
        log_info "  PG_DB_USER: ${PG_DB_USER:-not set}"
    fi
    log_info "  GEMINI_MODEL: ${GEMINI_MODEL:-not set}"
    if [[ -n "$GEMINI_API_KEY" ]]; then
        log_info "  GEMINI_API_KEY: ${GEMINI_API_KEY:0:10}... (masked)"
    else
        log_info "  GEMINI_API_KEY: not set"
    fi
}

# Comprehensive Gemini API test
test_gemini_api() {
    log_info "Running comprehensive Gemini API tests..."
    
    if [[ -z "$GEMINI_API_KEY" ]]; then
        log_error "GEMINI_API_KEY not found in environment"
        return 1
    fi
    
    if [[ -z "$GEMINI_MODEL" ]]; then
        log_warning "GEMINI_MODEL not set, using default: gemini-2.0-flash-exp"
        GEMINI_MODEL="gemini-2.0-flash-exp"
    fi
    
    log_info "Model: $GEMINI_MODEL"
    log_info "API Key: ${GEMINI_API_KEY:0:10}..."
    
    local api_url="https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}"
    local test_passed=0
    local test_total=0
    
    # Test 1: Basic connectivity and response parsing
    log_info "Test 1/5: Basic connectivity..."
    ((test_total++))
    local payload1=$(cat <<EOF
{
  "contents": [{
    "parts": [{
      "text": "Say exactly: API Test Successful"
    }]
  }],
  "generationConfig": {
    "temperature": 0.1,
    "maxOutputTokens": 50
  }
}
EOF
)
    
    local response1=$(curl -s --connect-timeout 10 --max-time 30 \
        -H "Content-Type: application/json" \
        -d "$payload1" "$api_url" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && ! echo "$response1" | grep -q '"error"'; then
        local text1=$(echo "$response1" | grep -o '"text"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
        if [[ -n "$text1" ]]; then
            log_success "✓ Basic connectivity: $text1"
            ((test_passed++))
        else
            log_error "✗ No response text found"
        fi
    else
        log_error "✗ Basic connectivity failed"
    fi
    
    # Test 2: E-commerce context understanding
    log_info "Test 2/5: E-commerce context..."
    ((test_total++))
    local payload2=$(cat <<EOF
{
  "contents": [{
    "parts": [{
      "text": "You are an e-commerce assistant. Customer asks: 'Do you have laptops?' Respond briefly about helping with product search."
    }]
  }],
  "generationConfig": {
    "temperature": 0.3,
    "maxOutputTokens": 100
  }
}
EOF
)
    
    local response2=$(curl -s --connect-timeout 10 --max-time 30 \
        -H "Content-Type: application/json" \
        -d "$payload2" "$api_url" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && ! echo "$response2" | grep -q '"error"'; then
        local text2=$(echo "$response2" | grep -o '"text"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' | head -1)
        if [[ -n "$text2" ]]; then
            log_success "✓ E-commerce context: ${text2:0:60}..."
            ((test_passed++))
        else
            log_error "✗ E-commerce context failed"
        fi
    else
        log_error "✗ E-commerce context request failed"
    fi
    
    # Test 3: JSON structure validation
    log_info "Test 3/5: Response structure..."
    ((test_total++))
    if echo "$response1" | grep -q '"candidates"' && echo "$response1" | grep -q '"content"'; then
        log_success "✓ Valid JSON structure"
        ((test_passed++))
    else
        log_error "✗ Invalid JSON structure"
    fi
    
    # Test 4: Error handling
    log_info "Test 4/5: Error handling..."
    ((test_total++))
    local invalid_response=$(curl -s --connect-timeout 5 --max-time 10 \
        -H "Content-Type: application/json" \
        -d '{"invalid": "payload"}' "$api_url" 2>/dev/null)
    
    if echo "$invalid_response" | grep -q '"error"'; then
        log_success "✓ Error handling works"
        ((test_passed++))
    else
        log_warning "⚠ Error handling unclear"
    fi
    
    # Test 5: Performance check
    log_info "Test 5/5: Performance..."
    ((test_total++))
    local start_time=$(date +%s%N)
    curl -s --connect-timeout 5 --max-time 15 \
        -H "Content-Type: application/json" \
        -d "$payload1" "$api_url" > /dev/null 2>&1
    local end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $duration_ms -lt 10000 ]]; then
        log_success "✓ Performance: ${duration_ms}ms"
        ((test_passed++))
    else
        log_warning "⚠ Performance: ${duration_ms}ms (slow)"
    fi
    
    # Summary
    log_info "Gemini API Tests: $test_passed/$test_total passed"
    if [[ $test_passed -ge 3 ]]; then
        log_success "Gemini API comprehensive test PASSED!"
        return 0
    else
        log_error "Gemini API comprehensive test FAILED!"
        return 1
    fi
}

# Comprehensive database connectivity test
test_database() {
    log_info "Running comprehensive database tests..."
    
    # Check required environment variables for MySQL
    local missing_mysql_vars=()
    [[ -z "$DB_HOST" ]] && missing_mysql_vars+=("DB_HOST")
    [[ -z "$DB_USER" ]] && missing_mysql_vars+=("DB_USER")
    [[ -z "$DB_PASSWORD" ]] && missing_mysql_vars+=("DB_PASSWORD")
    [[ -z "$DB_NAME" ]] && missing_mysql_vars+=("DB_NAME")
    [[ -z "$DB_PORT" ]] && missing_mysql_vars+=("DB_PORT")
    
    # Check PostgreSQL environment variables
    local missing_pg_vars=()
    [[ -z "$PG_DB_HOST" ]] && missing_pg_vars+=("PG_DB_HOST")
    [[ -z "$PG_DB_USER" ]] && missing_pg_vars+=("PG_DB_USER")
    [[ -z "$PG_DB_PASSWORD" ]] && missing_pg_vars+=("PG_DB_PASSWORD")
    [[ -z "$PG_DB_NAME" ]] && missing_pg_vars+=("PG_DB_NAME")
    [[ -z "$PG_DB_PORT" ]] && missing_pg_vars+=("PG_DB_PORT")
    
    local has_mysql=true
    local has_postgres=true
    
    if [[ ${#missing_mysql_vars[@]} -gt 0 ]]; then
        log_warning "Missing MySQL environment variables:"
        printf "   - %s\n" "${missing_mysql_vars[@]}"
        has_mysql=false
    fi
    
    if [[ ${#missing_pg_vars[@]} -gt 0 ]]; then
        log_warning "Missing PostgreSQL environment variables:"
        printf "   - %s\n" "${missing_pg_vars[@]}"
        has_postgres=false
    fi
    
    if [[ "$has_mysql" == "false" ]] && [[ "$has_postgres" == "false" ]]; then
        log_error "No database configuration found (need either MySQL or PostgreSQL)"
        return 1
    fi
    
    local test_passed=0
    local test_total=0
    
    # MySQL Tests
    if [[ "$has_mysql" == "true" ]]; then
        log_info "=== MYSQL TESTS ==="
        log_info "Database: $DB_NAME"
        log_info "Host: $DB_HOST:$DB_PORT"
        log_info "User: $DB_USER"
        
        # Test 1: MySQL Network connectivity
        log_info "Test 1/8: MySQL network connectivity..."
        ((test_total++))
        if timeout 5 bash -c "exec 3<>/dev/tcp/$DB_HOST/$DB_PORT" 2>/dev/null; then
            log_success "✓ TCP connection to $DB_HOST:$DB_PORT"
            ((test_passed++))
        else
            log_error "✗ Cannot connect to $DB_HOST:$DB_PORT"
        fi
        
        # Test 2: MySQL client availability
        log_info "Test 2/8: MySQL client..."
        ((test_total++))
        if command -v mysql >/dev/null 2>&1; then
            log_success "✓ MySQL client available"
            ((test_passed++))
        else
            log_error "✗ MySQL client not found"
        fi
        
        # Test 3: MySQL authentication
        log_info "Test 3/8: MySQL authentication..."
        ((test_total++))
        local mysql_connection_test=$(LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu mysql \
            --connect-timeout=10 \
            -h "$DB_HOST" \
            -P "$DB_PORT" \
            -u "$DB_USER" \
            -p"$DB_PASSWORD" \
            -D "$DB_NAME" \
            -e "SELECT 1 as test;" 2>&1)
        
        if [[ $? -eq 0 ]]; then
            log_success "✓ MySQL authentication successful"
            ((test_passed++))
        else
            log_error "✗ MySQL authentication failed"
            echo "   Error: $(echo "$mysql_connection_test" | grep -v "Warning" | head -1)"
        fi
        
        # Test 4: WordPress/WooCommerce tables
        log_info "Test 4/8: WordPress tables..."
        ((test_total++))
        local wp_tables=$(LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu mysql \
            --connect-timeout=10 \
            -h "$DB_HOST" \
            -P "$DB_PORT" \
            -u "$DB_USER" \
            -p"$DB_PASSWORD" \
            -D "$DB_NAME" \
            -e "SHOW TABLES LIKE 'wp_%';" 2>/dev/null | wc -l)
        
        if [[ $? -eq 0 ]] && [[ $wp_tables -gt 5 ]]; then
            log_success "✓ WordPress tables found ($wp_tables tables)"
            ((test_passed++))
        else
            log_warning "⚠ WordPress tables not found or incomplete"
        fi
    fi
    
    # PostgreSQL Tests
    if [[ "$has_postgres" == "true" ]]; then
        log_info "=== POSTGRESQL TESTS ==="
        log_info "Database: $PG_DB_NAME"
        log_info "Host: $PG_DB_HOST:$PG_DB_PORT"
        log_info "User: $PG_DB_USER"
        
        # Test 5: PostgreSQL Network connectivity
        log_info "Test 5/8: PostgreSQL network connectivity..."
        ((test_total++))
        if timeout 5 bash -c "exec 3<>/dev/tcp/$PG_DB_HOST/$PG_DB_PORT" 2>/dev/null; then
            log_success "✓ TCP connection to $PG_DB_HOST:$PG_DB_PORT"
            ((test_passed++))
        else
            log_error "✗ Cannot connect to $PG_DB_HOST:$PG_DB_PORT"
        fi
        
        # Test 6: PostgreSQL client availability
        log_info "Test 6/8: PostgreSQL client..."
        ((test_total++))
        if command -v psql >/dev/null 2>&1; then
            log_success "✓ PostgreSQL client available"
            ((test_passed++))
        else
            log_error "✗ PostgreSQL client not found"
        fi
        
        # Test 7: PostgreSQL authentication
        log_info "Test 7/8: PostgreSQL authentication..."
        ((test_total++))
        local pg_connection_test=$(PGPASSWORD="$PG_DB_PASSWORD" psql \
            -h "$PG_DB_HOST" \
            -p "$PG_DB_PORT" \
            -U "$PG_DB_USER" \
            -d "$PG_DB_NAME" \
            -c "SELECT 1 as test;" \
            -t -A 2>&1)
        
        if [[ $? -eq 0 ]]; then
            log_success "✓ PostgreSQL authentication successful"
            ((test_passed++))
        else
            log_error "✗ PostgreSQL authentication failed"
            echo "   Error: $(echo "$pg_connection_test" | head -1)"
        fi
        
        # Test 8: PostgreSQL products table
        log_info "Test 8/8: PostgreSQL products table..."
        ((test_total++))
        local pg_products=$(PGPASSWORD="$PG_DB_PASSWORD" psql \
            -h "$PG_DB_HOST" \
            -p "$PG_DB_PORT" \
            -U "$PG_DB_USER" \
            -d "$PG_DB_NAME" \
            -c "SELECT COUNT(*) FROM products;" \
            -t -A 2>/dev/null)
        
        if [[ $? -eq 0 ]] && [[ "$pg_products" =~ ^[0-9]+$ ]]; then
            log_success "✓ PostgreSQL products table accessible with $pg_products products"
            ((test_passed++))
        else
            log_warning "⚠ PostgreSQL products table not accessible"
        fi
    fi
    
    # Summary
    log_info "Database Tests: $test_passed/$test_total passed"
    if [[ $test_passed -ge $((test_total * 60 / 100)) ]]; then  # Pass if 60% of tests pass
        log_success "Database comprehensive test PASSED!"
        return 0
    else
        log_error "Database comprehensive test FAILED!"
        return 1
    fi
}

# Main function
main() {
    echo "🔧 Service Connectivity Test"
    echo "=============================="
    echo
    
    local overall_success=true
    
    # Load environment variables
    if ! load_env; then
        exit 1
    fi
    
    echo
    
    # Test Gemini API
    echo "🔮 GEMINI API TEST"
    echo "-------------------"
    if test_gemini_api; then
        echo
    else
        overall_success=false
        echo
    fi
    
    # Test Database
    echo "🗄️  DATABASE TEST"
    echo "-------------------"
    if test_database; then
        echo
    else
        overall_success=false
        echo
    fi
    
    # Summary
    echo "📊 SUMMARY"
    echo "==========="
    if [[ "$overall_success" == "true" ]]; then
        log_success "All tests PASSED! ✨"
        exit 0
    else
        log_error "Some tests FAILED! 💥"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    --gemini|gemini)
        load_env && test_gemini_api
        ;;
    --database|database|db)
        load_env && test_database
        ;;
    --help|-h|help)
        echo "Usage: $0 [option]"
        echo
        echo "Options:"
        echo "  (no args)     Run all tests"
        echo "  --gemini      Test Gemini API only"
        echo "  --database    Test database only"
        echo "  --help        Show this help"
        ;;
    *)
        main
        ;;
esac