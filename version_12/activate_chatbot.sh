#!/bin/bash

# Activate Chatbot Script

echo "=== Activating Chatbot ==="
echo ""

# Navigate to the ecommerce_chatbot directory
cd ecommerce_chatbot

# Activate the virtual environment
echo "Activating virtual environment..."
apt install python3.12-venv
python3 -m venv venv
source venv/bin/activate

# Install requirements
pip install -r requirements.txt

# Configure the API endpoint
echo ""
echo "Configuring API endpoint..."
cd ..
./setup_chatbot_config.sh

# Start the Flask app
echo ""
echo "Starting Flask app..."
cd ecommerce_chatbot
python app.py