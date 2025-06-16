#!/bin/bash

# Chatbot Configuration Setup Script

echo "=== Chatbot API Configuration ==="
echo ""

# Get current server IP
SERVER_IP=$(hostname -I | awk '{print $1}')
EXTERNAL_IP=$(curl -s http://ipecho.net/plain 2>/dev/null || echo "")

echo "Detected Server IP: $SERVER_IP"
if [ ! -z "$EXTERNAL_IP" ]; then
    echo "Detected External IP: $EXTERNAL_IP"
fi
echo ""

echo "Choose API endpoint configuration:"
echo "1. Use detected server IP ($SERVER_IP)"
if [ ! -z "$EXTERNAL_IP" ]; then
    echo "2. Use external IP ($EXTERNAL_IP)"
fi
echo "3. Enter custom IP address"
echo "4. Use localhost (127.0.0.1)"
echo ""

read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        API_URL="http://$SERVER_IP:5000"
        ;;
    2)
        if [ ! -z "$EXTERNAL_IP" ]; then
            API_URL="http://$EXTERNAL_IP:5000"
        else
            echo "External IP not available, using server IP"
            API_URL="http://$SERVER_IP:5000"
        fi
        ;;
    3)
        read -p "Enter custom IP address: " CUSTOM_IP
        API_URL="http://$CUSTOM_IP:5000"
        ;;
    4)
        API_URL="http://127.0.0.1:5000"
        ;;
    *)
        echo "Invalid choice, using server IP as default"
        API_URL="http://$SERVER_IP:5000"
        ;;
esac

echo ""
echo "Selected API URL: $API_URL"

# Save to config file
echo "$API_URL" > chatbot_config.txt
echo "Configuration saved to chatbot_config.txt"

# Test the API
echo ""
echo "Testing API connection..."
if curl -s "$API_URL/message?input=hello" > /dev/null; then
    echo "✅ API connection successful!"
else
    echo "❌ API connection failed. Please check if Flask app is running on port 5000"
    echo "To start Flask app: cd ecommerce_chatbot && source venv/bin/activate && python3 app.py"
fi

echo ""
echo "Setup complete! The chatbot proxy will now use: $API_URL"