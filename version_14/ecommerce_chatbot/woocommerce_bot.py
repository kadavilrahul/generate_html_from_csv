from agno.agent import Agent, AgentMemory
from agno.models.google.gemini import Gemini
import os
from dotenv import load_dotenv
import csv
import mysql.connector
import psycopg2
import psycopg2.extras
#import gradio as gr
import re
from agno.storage.agent.sqlite import SqliteAgentStorage
from agno.memory.db.sqlite import SqliteMemoryDb

load_dotenv()

# Get API keys from environment variables
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
GEMINI_MODEL = os.getenv('GEMINI_MODEL', 'gemini-2.0-flash-exp')  # Default fallback

# MySQL Database credentials (for WooCommerce)
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = int(os.getenv("DB_PORT", 3306))  # Convert to int, default to 3306
DB_TABLE_PREFIX = os.getenv("DB_TABLE_PREFIX", "wp_")  # Default to wp_ if not set
WC_URL = os.getenv("WC_URL")

# PostgreSQL Database credentials (for products)
PG_DB_NAME = os.getenv("PG_DB_NAME")
PG_DB_USER = os.getenv("PG_DB_USER")
PG_DB_PASSWORD = os.getenv("PG_DB_PASSWORD")
PG_DB_HOST = os.getenv("PG_DB_HOST")
PG_DB_PORT = int(os.getenv("PG_DB_PORT", 5432))  # Convert to int, default to 5432

# Check if all required environment variables are set
missing_vars = []
if not GEMINI_API_KEY:
    missing_vars.append("GEMINI_API_KEY")
if not DB_NAME or not DB_USER or not DB_PASSWORD or not DB_HOST:
    missing_vars.append("MySQL credentials (DB_NAME, DB_USER, DB_PASSWORD, DB_HOST)")
if not WC_URL:
    missing_vars.append("WC_URL")

if missing_vars:
    raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

# Check PostgreSQL credentials (optional but log if incomplete)
pg_missing = []
if not PG_DB_NAME:
    pg_missing.append("PG_DB_NAME")
if not PG_DB_USER:
    pg_missing.append("PG_DB_USER")
if not PG_DB_PASSWORD:
    pg_missing.append("PG_DB_PASSWORD")
if not PG_DB_HOST:
    pg_missing.append("PG_DB_HOST")

if pg_missing:
    print(f"Warning: PostgreSQL credentials incomplete: {', '.join(pg_missing)}")
    print("PostgreSQL product search will be disabled.")
else:
    print("PostgreSQL credentials found - dual database search enabled.")

def load_faq(csv_file):
    """Load FAQ data from a CSV file"""
    faq_data = []
    try:
        print(f"Attempting to load FAQ from: {csv_file}")
        with open(csv_file, 'r', encoding='utf-8') as file:
            csv_reader = csv.reader(file, delimiter='\t')
            header = next(csv_reader)  # Skip header row
            print(f"CSV Header: {header}")
            row_count = 0
            for row in csv_reader:
                row_count += 1
                if len(row) >= 2:
                    faq_data.append({'question': row[0], 'answer': row[1]})
                    if row_count <= 3:  # Show first 3 entries for debugging
                        print(f"Loaded FAQ {row_count}: Q='{row[0][:50]}...' A='{row[1][:50]}...'")
                else:
                    print(f"Skipping row {row_count} with missing values: {row}")
        print(f"Successfully loaded {len(faq_data)} FAQ entries")
        return faq_data
    except FileNotFoundError:
        print(f"Error: FAQ file '{csv_file}' not found.")
        return []
    except Exception as e:
        print(f"Error loading FAQ data: {e}")
        return []

def get_order_status(email: str = None, order_id: str = None) -> str:
    """Tool to retrieve order status based on email or order ID"""
    if not email and not order_id:
        return "Please provide either an email address or order ID."
    
    try:
        mydb = mysql.connector.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            port=DB_PORT
        )
        mycursor = mydb.cursor(dictionary=True)

        # Construct the SQL query to retrieve the order status
        query = """
        SELECT
            p.ID as order_id,
            p.post_status as order_status,
            p.post_date as order_date,
            MAX(CASE WHEN pm.meta_key = '_billing_first_name' THEN pm.meta_value END) as first_name,
            MAX(CASE WHEN pm.meta_key = '_billing_last_name' THEN pm.meta_value END) as last_name,
            MAX(CASE WHEN pm.meta_key = '_order_total' THEN pm.meta_value END) as total
        FROM
            wp_posts p
        JOIN wp_postmeta pm ON p.ID = pm.post_id
        WHERE
            p.post_type = 'shop_order'
        """
        
        params = []
        if order_id:
            query += " AND p.ID = %s"
            params.append(order_id)
        if email:
            query += " AND p.ID IN (SELECT post_id FROM wp_postmeta WHERE meta_key = '_billing_email' AND meta_value = %s)"
            params.append(email)
            
        query += " GROUP BY p.ID ORDER BY p.post_date DESC LIMIT 5"
        
        mycursor.execute(query, params)
        myresult = mycursor.fetchall()
        
        if myresult:
            result = ["Here are the order details:"]
            for row in myresult:
                order_date = row['order_date'].strftime('%Y-%m-%d %H:%M:%S') if row['order_date'] else 'N/A'
                status_mapping = {
                    'wc-pending': 'Pending payment',
                    'wc-processing': 'Processing',
                    'wc-on-hold': 'On hold',
                    'wc-completed': 'Completed',
                    'wc-cancelled': 'Cancelled',
                    'wc-refunded': 'Refunded',
                    'wc-failed': 'Failed'
                }
                status = status_mapping.get(row['order_status'], row['order_status'])
                
                result.append(f"Order #{row['order_id']}")
                result.append(f"Date: {order_date}")
                result.append(f"Customer: {row.get('first_name', '')} {row.get('last_name', '')}")
                result.append(f"Total: Rs.{row.get('total', 'N/A')}")
                result.append(f"Status: {status}")
                result.append("---")
            
            return "\n".join(result)
        else:
            if order_id:
                return f"No order found with ID {order_id}."
            else:
                return f"No orders found for email {email}."

    except mysql.connector.Error as e:
        return f"Database error: {e}"
    except Exception as e:
        return f"An error occurred: {e}"
    finally:
        if 'mydb' in locals() and mydb:
            mydb.close()

def search_products_postgres(product_name: str) -> tuple:
    """Search for products in PostgreSQL database"""
    # Check if PostgreSQL is configured
    if not PG_DB_NAME or not PG_DB_USER or not PG_DB_PASSWORD or not PG_DB_HOST:
        return [], "PostgreSQL not configured"
    
    # Check for placeholder values
    if (PG_DB_NAME == "your_postgres_db_name" or 
        PG_DB_USER == "your_postgres_user" or 
        PG_DB_PASSWORD == "your_postgres_password"):
        return [], "PostgreSQL has placeholder credentials"
    
    try:
        conn = psycopg2.connect(
            host=PG_DB_HOST,
            database=PG_DB_NAME,
            user=PG_DB_USER,
            password=PG_DB_PASSWORD,
            port=PG_DB_PORT
        )
        cursor = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
        
        # Search in products table (using actual column names: title, not name)
        query = """
        SELECT id, title, price, category, product_link, image_url
        FROM products 
        WHERE title ILIKE %s
        LIMIT 10;
        """
        
        search_term = f"%{product_name}%"
        cursor.execute(query, (search_term,))
        results = cursor.fetchall()
        
        products = []
        for row in results:
            products.append({
                'id': row['id'],
                'name': row['title'],  # Map title to name for consistency
                'price': row['price'],
                'category': row['category'],
                'link': row['product_link'],
                'image_url': row['image_url'],
                'source': 'PostgreSQL'
            })
        
        return products, None
        
    except psycopg2.Error as e:
        error_msg = f"PostgreSQL database error: {e}"
        print(error_msg)
        return [], error_msg
    except Exception as e:
        error_msg = f"PostgreSQL connection error: {e}"
        print(error_msg)
        return [], error_msg
    finally:
        if 'conn' in locals() and conn:
            conn.close()

def search_products_mysql(product_name: str) -> list:
    """Search for products in MySQL/WooCommerce database"""
    try:
        mydb = mysql.connector.connect(
            host=DB_HOST,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            port=DB_PORT
        )
        mycursor = mydb.cursor()

        # Use parameterized query for security (using configurable table prefix)
        query = f"""
        SELECT
            p.ID,
            p.post_title,
            pm.meta_value 
        FROM
            {DB_TABLE_PREFIX}posts p 
        LEFT JOIN {DB_TABLE_PREFIX}postmeta pm ON p.ID = pm.post_id 
        WHERE
            p.post_type = 'product'
            AND p.post_status = 'publish'
            AND p.post_title LIKE %s 
            AND pm.meta_key = '_price'
        LIMIT 10;
        """
        
        search_term = f"%{product_name}%"
        mycursor.execute(query, (search_term,))
        myresult = mycursor.fetchall()
        
        products = []
        for row in myresult:
            product_id = row[0]
            product_title = row[1]
            product_link = f"{WC_URL}/product/{product_title.lower().replace(' ', '-')}"
            product_price = row[2]
            products.append({
                'id': product_id,
                'name': product_title,
                'price': product_price,
                'link': product_link,
                'source': 'WooCommerce'
            })
        
        return products
        
    except mysql.connector.Error as e:
        print(f"MySQL error: {e}")
        return []
    except Exception as e:
        print(f"MySQL search error: {e}")
        return []
    finally:
        if 'mydb' in locals() and mydb:
            mydb.close()

def search_products(product_name: str) -> str:
    """Tool to search for products by name in both MySQL and PostgreSQL databases"""
    if not product_name:
        return "Please provide a product name to search for."
    
    # Search in both databases
    mysql_products = search_products_mysql(product_name)
    postgres_products, pg_error = search_products_postgres(product_name)
    
    # Combine results
    all_products = mysql_products + postgres_products
    
    if all_products:
        if len(all_products) == 1:
            # Single product - conversational format like the working example
            product = all_products[0]
            response = f"Yes, we have a **{product['name']}** available for Rs. {product['price']}."
            
            if product.get('category'):
                response += f" You can find it in the {product['category']} category"
            
            if product.get('link'):
                response += f" [here]({product['link']})."
            else:
                response += "."
                
            return response
        else:
            # Multiple products - conversational list format
            response = f"Yes, we have several products matching '{product_name}':\n\n"
            
            for i, product in enumerate(all_products[:5], 1):  # Limit to 5 products
                response += f"{i}. **{product['name']}** - Rs. {product['price']}"
                if product.get('category'):
                    response += f" ({product['category']})"
                if product.get('link'):
                    response += f" [View Product]({product['link']})"
                response += "\n"
            
            if len(all_products) > 5:
                response += f"\n...and {len(all_products) - 5} more products available."
            
            return response
    else:
        # No products found - conversational format like the working example
        return f"I'm sorry, I couldn't find any products that match \"{product_name}\" in our catalog. Please check back later as our inventory is constantly updated. Is there anything else I can help you with?"

# Load FAQ data
# Get the directory where this script is located
script_dir = os.path.dirname(os.path.abspath(__file__))
faq_file_path = os.path.join(script_dir, 'faq.csv')
print(f"Looking for FAQ file at: {faq_file_path}")
print(f"FAQ file exists: {os.path.exists(faq_file_path)}")
faq_data = load_faq(faq_file_path)
print(f"Loaded {len(faq_data)} FAQ entries")

# Create the FAQ Agent
faq_agent = Agent(
    name="FAQ Agent",
    role="Answer questions based on the provided FAQ data",
    model=Gemini(
        id=GEMINI_MODEL,
        api_key=GEMINI_API_KEY,
        generative_model_kwargs={},
        generation_config={}
    ),
    instructions=f"""You are an FAQ assistant for an e-commerce store. 
    Use the following FAQ data to answer questions: {faq_data}
    If you don't find a direct answer in the FAQ data, provide a helpful response based on general e-commerce knowledge.
    Always be polite and professional.""",
    show_tool_calls=False,  # Hide tool calls
    markdown=True,
)

# Create the Order Status Agent
order_status_agent = Agent(
    name="Order Status Agent",
    role="Retrieve order status based on email or order ID",
    model=Gemini(
        id=GEMINI_MODEL,
        api_key=GEMINI_API_KEY,
        generative_model_kwargs={},
        generation_config={}
    ),
    tools=[get_order_status],
    instructions="""You are an order status assistant. 
    Use the get_order_status tool to retrieve order status information.
    Always ask for either an email address or order ID if the user doesn't provide one.
    Explain what each order status means in customer-friendly language.""",
    show_tool_calls=False,  # Hide tool calls
    markdown=True,
)

# Create the Product Search Agent
product_search_agent = Agent(
    name="Product Search Agent",
    role="Search for products by name",
    model=Gemini(
        id=GEMINI_MODEL,
        api_key=GEMINI_API_KEY,
        generative_model_kwargs={},
        generation_config={}
    ),
    tools=[search_products],
    instructions="""You are a product search assistant.
    Use the search_products tool to find products based on the user's query.
    If the user asks about products or mentions looking for something, help them find it.
    Always ask for clarification if the product name is ambiguous.""",
    show_tool_calls=False,  # Hide tool calls
    markdown=True,
)

# Create the Agent Team
agent_team = Agent(
    team=[faq_agent, order_status_agent, product_search_agent],

    storage=SqliteAgentStorage(table_name='agent_sessions', db_file='tmp/data.db'),
    add_history_to_messages=True,
    num_history_responses=100,
    model=Gemini(
        id=GEMINI_MODEL,
        api_key=GEMINI_API_KEY,
        generative_model_kwargs={},
        generation_config={}
    ),
    instructions="""You are an e-commerce assistant for our WooCommerce store.
    
    Your capabilities include:
    1. Answering frequently asked questions about our store, products, shipping, returns, etc.
    2. Checking order status when customers provide their email or order ID
    3. Helping customers find products by searching our product catalog
    
    Delegate tasks to the appropriate sub-agent based on the user's query.
    
    Always be helpful, friendly, and professional. If you're unsure about something, acknowledge that and offer alternative assistance.
    
    Start conversations by introducing yourself as the store's virtual assistant and briefly mentioning what you can help with.
    """,
    show_tool_calls=False,  # Hide tool calls
    markdown=True,
)

# Function to clean agent status messages from the response
def clean_agent_status(text):
    # Remove lines that contain agent status messages
    if not text:
        return text
        
    # Remove "Running: transfer_task_to..." messages
    text = re.sub(r'Running: transfer_task_to_\w+\(.*?\)', '', text)
    
    # Remove other potential agent status messages
    text = re.sub(r'Running: \w+\(.*?\)', '', text)
    
    # Remove empty lines that might be left after removing status messages
    text = re.sub(r'\n\s*\n', '\n', text)
    
    return text.strip()

# Function to process user queries for Gradio
def process_query(message, history):
    try:
        # Get the response from the agent
        response = agent_team.run(message)
        
        # Extract just the content from the RunResponse object
        if hasattr(response, 'content'):
            # If it's a RunResponse object, get just the content
            response_text = response.content
        else:
            # If it's already a string, use it directly
            response_text = str(response)
        
        # Clean any agent status messages from the response
        response_text = clean_agent_status(response_text)
            
        # Return the user message and bot response as a tuple
        return response_text
    except Exception as e:
        return f"An error occurred: {e}\nPlease try again with a different query."

