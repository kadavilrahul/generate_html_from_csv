# 🛒 ChatBot Assistant for Ecommerce website

An intelligent chatbot assistant for Ecommerce stores that helps customers with order status inquiries, product searches, and frequently asked questions.

## Introduction

- The Chatbot Assistant provides customer support features like order status tracking, product search, and FAQ assistance. 
- Cuurenty version is set up foe Woocommerce website
- It queries MySQL database of Wordpress to retrieve data about order status tracking, product search
- It also queries CSV file saved in the project folder for FAQ assistance
- It processes the data using LLM API to respond to the user

## ✨ Features

- 📦 **Order Status Tracking**: Check order status using email address or order ID
- 🔍 **Product Search**: Find products in your WooCommerce catalog
- ❓ **FAQ Assistance**: Answer common customer questions using a customizable FAQ database
- 🧠 **Intelligent Routing**: Automatically routes queries to the appropriate service
- 🌐 **Web Integration**: Easy to integrate with any website via REST API

## 🛠️ Technology Stack

- **Language**: Python
- **Backend**: Flask (Python library)
- **AI Model**: Google Gemini AI (LLM)
- **Database**: MySQL (WooCommerce database)
- **Agent Framework**: Agno (Python library)
- **Frontend**: HTML/JavaScript (Sample included)

## 📋 Prerequisites

- Python 3.12.0 or higher
- WooCommerce store with MySQL database
- Google Gemini API key
- MySQL database credentials

## 📁 Project Structure

```
/public/
│
├── Readme.md
├── app.py                  ← Flask backend
├── woocommerce_bot.py      ← AI logic using Gemini + WooCommerce DB
├── .env                    ← Environment variables
├── faq.csv                 ← Tab-delimited FAQ list
├── requirements.txt        ← Python dependencies
│── sample.html             ← Example chatbot integration  
│── images/                 ← Folder containing image for sample.html
    ├── sample.webp         ← Image for sample.html
└── chatbot/                ← Frontend UI folder (served to users)
    ├── widget.html         ← Chatbot interface
    ├── css/
    │   ├── materialize.min.css
    │   └── style.css
    ├── js/
    │   ├── chart.min.js
    │   ├── jquery.min.js
    │   ├── materialize.min.js
    │   └── script.js
    └── img/
        └── image files...
```

- `app.py`: Flask application entry point
- `woocommerce_bot.py`: Core bot functionality and agent definitions
- `faq.csv`: Customizable FAQ database
- `requirements.txt`: Python dependencies
- `Chatbot/`: Frontend implementation

---

## 🚀 Installation

1. Clone the repository's folders and files to the current folder:
   ```bash
   git clone https://github.com/kadavilrahul/ecommerce_chatbot.git
   ```
   ```bash
   cd ecommerce_chatbot
   ```

2. Move files to the required folder as needed

3. Create and activate a virtual environment:
   ```bash
   apt install python3.12-venv
   ```
   ```bash
   python3 -m venv venv
   ```
   ```bash
   source venv/bin/activate
   ```

4. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

5. Create a `.env` file with your credentials (based on sample.env.txt):
   ```
   DB_NAME=your_db
   DB_USER=your_user
   DB_PASSWORD=your_password
   DB_HOST=your_server_ip_address
   WC_URL=https://your_website.com
   GEMINI_API_KEY=your_api_key
   DB_PORT=3306
   ```

6. Prepare your FAQ data in a CSV file named `faq.csv` in the project root directory. Use tab-separated format. Check sample faq.csv file.
   ```
   question	answer
   How do I reset my password?	Click the "Forgot Password" link on the login page and follow the instructions.
   ```

7. Add Chat Widget to Your Web Page

Add the following snippet between </script> and </body> of HTML page at the bottom:
See image for refernece
![alt text](iframe_integration.png)

```html

<!-- Floating Chatbot Widget -->
<div style="position: fixed; bottom: 24px; right: 24px; width: 750px; height: 550px; z-index: 9999;">
  <iframe 
    src="chatbot/widget.html" 
    frameborder="0" 
    style="width:100%; height:100%;" 
    scrolling="no"
    title="Customer Support Chatbot">
  </iframe>
</div>

```
8. Modify line 3 in file chatbot/js/script.js
   const URL_API = "http://IP_ADDRESS_OR_DOMINANAME:5000";
   Enter either IP Address or domain name
   
8. Start the backend service:

   ```bash
   python app.py
   ```

9. You may check the chatbot functionality in the existing sample.html. 
   If you have kept all files on your domain root line html folder then on browser enter below.

   ```bash
   your-server-ip/sample.html
   ```
   
10. If you get error "Port 5000 is in use by another program"

   Run this command to find the process ID (PID) using port 5000:
   ```bash
   sudo lsof -i :5000
   ```
   You’ll see output like:

   COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
   python3  1234 root    3u  IPv4  12345      0t0  TCP *:5000 (LISTEN)
   How to Kill the Processes
   Run:
   ```bash
   sudo kill -9 12730 12741
   ```

   After killing, check again:
   ```bash
   sudo lsof -i :5000
   ```

## 🏃‍♀️ Note

### 1. Place `chatbot/` Folder in Your Site Root

Ensure the `widget.html` and its subfolders are publically accessible (e.g. `https://yourstore.com/chatbot/widget.html`).


### 2. The chatbot exposes a simple REST API:

```
GET /message?input=your_question_here
```

Example response:
```json
{
  "result": "Here are the products that match your search..."
}
```

### 3. How It Works

1. The **frontend widget** is a standalone HTML page (`widget.html`) rendered in an `<iframe>`.
2. When a user types a message, JavaScript sends a GET request to:
   ```
   http://localhost:5000/message?input=hello
   ```
3. The Flask app (`app.py`) processes the query using your `woocommerce_bot.py` logic and returns a JSON response.
4. The frontend displays the result as chat.

---

### 4. Customization

### FAQ Database
Edit the `faq.csv` file to customize the frequently asked questions and answers. The format should be tab-separated with "question" and "answer" columns.

### Agent Behavior
You can modify the agent instructions in `woocommerce_bot.py` to customize how the bot interacts with users.

### 5. Deployment

- Make sure your backend server (`app.py`) is accessible from your site (CORS is already enabled).
- Ensure your `.env` file is secured in production.
- Use HTTPS for secure communication.

### 6. User Instructions

Users can interact with the chatbot by using the embedded iframe. They can type their questions or requests directly into the chat interface within the iframe and receive responses from the chatbot.

### 7. Developer Instructions

Integrating the WooCommerce Chatbot using the iframe method involves including the chatbot's frontend files and adding an iframe element to your website's HTML.

## 🤝 Contribution

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
