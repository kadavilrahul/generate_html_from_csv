# E-commerce Chatbot with WooCommerce Integration
A Flask-based AI chatbot that integrates with WooCommerce stores to provide customer support, order tracking, and product search capabilities.

## 🚀 Quick Start

### Clone Repository

```bash
git clone https://github.com/kadavilrahul/generate_html_from_csv
```

```bash
cd generate_html_from_csv
```

```bash
bash run.sh
```

## Prerequisites

Before you begin, make sure you have:

1. Python 3.8 or higher installed
2. Node.js version 16 or higher
3. PostgreSQL database server
4. MySQL database server (for WooCommerce)
5. Apache2 web server
6. Git for version control

## Installation Steps

1. Configure your environment variables:
   ```bash
   cp ecommerce_chatbot/sample.env ecommerce_chatbot/.env
   nano ecommerce_chatbot/.env  # Edit with your actual values
   ```

2. Get your Gemini API key from Google AI Studio:
   - Visit https://makersuite.google.com/app/apikey
   - Create a new API key and add it to your .env file

3. Set up your database credentials in the .env file:
   ```bash
   # Add your MySQL WooCommerce database details
   # Add your PostgreSQL product database details
   # Configure your WooCommerce store URL
   ```

4. Install Python dependencies (handled automatically by run.sh):
   ```bash
   cd ecommerce_chatbot && pip install -r requirements.txt
   ```

## Features

1. **AI-Powered Customer Support** - Uses Google Gemini AI to answer customer questions
2. **Order Status Tracking** - Checks WooCommerce orders by email or order ID
3. **Product Search** - Searches both MySQL and PostgreSQL product databases
4. **FAQ System** - Loads answers from CSV file for common questions
5. **Web Interface** - Complete HTML/CSS/JS frontend for chat interactions
6. **Session Management** - Stores conversation history using SQLite
7. **Multi-Database Support** - Works with both WooCommerce MySQL and PostgreSQL

## Project Structure

1. `ecommerce_chatbot/` - Main chatbot application directory (8 files)
2. `ecommerce_chatbot/app.py` - Flask web server that handles API requests
3. `ecommerce_chatbot/woocommerce_bot.py` - Core chatbot logic with AI agents
4. `ecommerce_chatbot/requirements.txt` - Python package dependencies
5. `ecommerce_chatbot/faq.csv` - FAQ questions and answers database
6. `ecommerce_chatbot/chatbot/` - Frontend HTML interface with CSS/JS
7. `run.sh` - Main setup script that configures everything automatically
8. `setup.sh` - Apache and system configuration script

## Configuration

### Environment Variables (.env file)

1. **Database Settings**:
   ```bash
   DB_NAME=your_woocommerce_database
   DB_USER=your_mysql_username
   DB_PASSWORD=your_mysql_password
   DB_HOST=localhost
   ```

2. **AI Configuration**:
   ```bash
   GEMINI_API_KEY=your_gemini_api_key
   GEMINI_MODEL=gemini-2.0-flash
   ```

3. **WooCommerce Integration**:
   ```bash
   WC_URL=https://your-store.com
   DB_TABLE_PREFIX=wp_
   ```

## Usage Instructions

1. **Start the chatbot**:
   ```bash
   bash run.sh  # This handles everything automatically
   ```

2. **Access the web interface**:
   - The chatbot will be available at the URL shown in terminal
   - Usually runs on http://your-server-ip:5000

3. **Test chatbot features**:
   - Ask about products: "Do you have iPhone cases?"
   - Check orders: "What's the status of order #123?"
   - Get help: "How do I return an item?"

## API Endpoints

1. **GET /message** - Main chatbot endpoint
   - Parameter: `input` (user message)
   - Returns: JSON response with chatbot reply

## Troubleshooting

1. **Problem**: Chatbot not responding
   **Solution**: Check if Flask app is running with `ps aux | grep python`

2. **Problem**: Database connection failed
   **Solution**: Verify your .env file has correct database credentials

3. **Problem**: Gemini API errors
   **Solution**: Check your API key is valid and has sufficient quota

4. **Problem**: Port already in use
   **Solution**: The app automatically finds available ports 5000-5010

5. **Problem**: Missing Python packages
   **Solution**: Run `pip install -r ecommerce_chatbot/requirements.txt`

## Getting Help

If you need assistance:
1. Check the troubleshooting section above
2. Review the .env configuration file
3. Check Flask application logs in ecommerce_chatbot/flask_app.log
4. Create an issue on the GitHub repository

## License
MIT License - You can freely use this project