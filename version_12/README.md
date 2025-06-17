# Static WooCommerce Product Pages Generator with AI Chatbot

A complete solution that converts CSV product data into static HTML pages served directly by Apache, bypassing WordPress for better performance while maintaining WordPress admin functionality. Includes an intelligent AI chatbot for customer support.

## 🚀 Features

### Static Page Generator
- **CSV to HTML**: Converts product data into individual HTML pages
- **Static Serving**: Serves pages directly via Apache (faster than WordPress)
- **Clean URLs**: SEO-friendly URLs without file extensions (`/products/product-name`)
- **Auto Images**: Downloads and optimizes product images automatically
- **Incremental**: Only processes changed products for efficiency
- **WordPress Compatible**: Maintains WordPress backend for admin/management

### AI Chatbot Assistant
- 📦 **Order Status Tracking**: Check order status using email address or order ID
- 🔍 **Product Search**: Find products in your WooCommerce catalog
- ❓ **FAQ Assistance**: Answer common customer questions using a customizable FAQ database
- 🧠 **Intelligent Routing**: Automatically routes queries to the appropriate service
- 🌐 **Web Integration**: Easy to integrate with any website via REST API

## 🛠️ Technology Stack

- **Backend**: Node.js, Gulp, EJS templating
- **AI Chatbot**: Python, Flask, Google Gemini AI
- **Database**: PostgreSQL (for products), MySQL (for WooCommerce)
- **Web Server**: Apache2 with mod_rewrite
- **Frontend**: HTML, CSS, JavaScript

## 📋 Prerequisites

- Ubuntu/Debian server with Apache2 installed
- Node.js and npm
- Python 3.12+ (for chatbot)
- PostgreSQL (for product database)
- MySQL (for WooCommerce integration)
- Root access
- Domain pointing to your server (optional for testing)

## 🚀 Quick Setup

### 1. Installation

```bash
# Clone or download the project files
# Navigate to the project directory
cd /path/to/generate_html_from_csv/version_12
```

### 2. Generate Static Product Pages

```bash
# Run the main script
bash run.sh
```

**Follow the prompts:**
- Select your domain folder (e.g., `/var/www/example.com`)
- Choose generation mode (incremental/force)
- Configure database settings
- Optionally enable chatbot integration

### 3. Configure Chatbot (Optional)

If you chose to enable the chatbot during setup, you'll need to manually configure the environment file:

```bash
# Edit the chatbot configuration
nano ecommerce_chatbot/.env
```

Fill in the required values:
```env
DB_NAME=your_database_name
DB_USER=your_database_user
DB_PASSWORD=your_database_password
DB_HOST=localhost
DB_PORT=5432
WC_URL=https://your-domain.com
GEMINI_API_KEY=your_gemini_api_key
```

Get your Gemini API key from: https://makersuite.google.com/app/apikey

## 📁 Project Structure

```
/generate_html_from_csv/version_12/
├── run.sh                      # Main execution script
├── setup.sh                    # System setup script
├── gulpfile.js                 # Build configuration
├── package.json                # Node.js dependencies
├── products.csv                # Your product data
├── product.ejs                 # HTML template for products
├── product_with_chatbot.ejs    # Template with chatbot integration
├── search.php                  # Product search functionality
├── chatbot_proxy.php           # Chatbot API proxy
└── ecommerce_chatbot/          # AI Chatbot directory
    ├── app.py                  # Flask backend
    ├── woocommerce_bot.py      # AI logic using Gemini
    ├── .env                    # Environment variables (configure manually)
    ├── faq.csv                 # FAQ database
    ├── requirements.txt        # Python dependencies
    └── chatbot/                # Frontend UI
        ├── css/
        ├── js/
        └── img/
```

## 📊 CSV Format

Your `products.csv` should have these columns:
```csv
Image,Title,Regular Price,Category,Short_description,description
```

## 🌐 What Gets Generated

### File Structure Created
```
/var/www/yourdomain.com/
├── [WordPress files]           # Your existing WordPress
├── public/
│   ├── products/              # Generated HTML files
│   │   └── .htaccess         # URL rewriting rules
│   └── images/               # Product images
├── chatbot_proxy.php          # Chatbot API proxy (if enabled)
└── chatbot_config.txt         # Chatbot configuration (if enabled)
```

### URL Structure
- **WordPress**: `yourdomain.com/` (admin, other pages)
- **Static Products**: `yourdomain.com/products/product-name`
- **Product Images**: `yourdomain.com/images/image-name.jpg`
- **Chatbot API**: `yourdomain.com/chatbot_proxy.php`

## 🔧 System Configuration

The setup script automatically:
- ✅ Checks Apache and enables mod_rewrite
- ✅ Creates directory structure
- ✅ Sets proper file permissions
- ✅ Creates virtual host configuration
- ✅ Sets up URL aliases and clean URLs
- ✅ Configures basic caching
- ✅ Sets up PostgreSQL database for products
- ✅ Installs Python dependencies for chatbot (if enabled)

## 🧪 Testing Your Setup

### 1. Test Static File Serving
```bash
# Should return 200 OK after generating products
curl -I http://yourdomain.com/products/your-product-name
```

### 2. Test Clean URLs
```bash
# Both should work:
curl http://yourdomain.com/products/product-name
curl http://yourdomain.com/products/product-name.html
```

### 3. Test Chatbot (if enabled)
```bash
# Test chatbot API
curl "http://yourdomain.com/chatbot_proxy.php?input=hello"
```

## 🚀 Performance Benefits

### Before (WordPress)
- ⏱️ 2-5 seconds page load time
- 🔄 Database queries for each request
- 💾 High server resource usage

### After (Static Pages)
- ⚡ 0.2-0.5 seconds page load time
- 🚀 Direct file serving by Apache
- 💡 Minimal server resource usage

## 🛠️ Troubleshooting

### Common Issues

**1. "403 Forbidden" Error**
```bash
# Check permissions
chown -R www-data:www-data /var/www/yourdomain.com/public
chmod -R 755 /var/www/yourdomain.com/public
```

**2. "mod_rewrite not working"**
```bash
# Enable mod_rewrite
a2enmod rewrite
systemctl restart apache2
```

**3. Chatbot not responding**
```bash
# Check if Flask app is running
ps aux | grep "python.*app.py"

# Check chatbot configuration
cat ecommerce_chatbot/chatbot_config.txt
```

**4. Database connection issues**
```bash
# Test PostgreSQL connection
psql -h localhost -U your_user -d your_database -c "SELECT 1;"
```

### Log Files
- **Apache Error Log**: `/var/log/apache2/error_yourdomain.com.log`
- **Apache Access Log**: `/var/log/apache2/access_yourdomain.com.log`
- **Chatbot Log**: `ecommerce_chatbot/flask_app.log` (when running)

```bash
# Monitor logs in real-time
tail -f /var/log/apache2/error_yourdomain.com.log
```

## 🔒 Security Features

- ✅ Directory browsing disabled
- ✅ CSV files blocked from direct access
- ✅ Proper file permissions set
- ✅ Separate static content from WordPress core
- ✅ Environment variables secured
- ✅ CORS properly configured for chatbot

## 📱 Chatbot Integration

### Adding Chatbot to Your Pages

Add this snippet to your HTML pages where you want the chatbot:

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

### Chatbot API

The chatbot exposes a simple REST API:
```
GET /chatbot_proxy.php?input=your_question_here
```

Example response:
```json
{
  "result": "Here are the products that match your search..."
}
```

## 🎯 Usage Commands

```bash
# Basic usage
bash run.sh

# Force regeneration of all products
bash run.sh --force

# Enable chatbot automatically
bash run.sh --enable-chatbot

# Check .env configuration
bash run.sh --check-env

# Show configuration instructions
bash run.sh --populate-env

# Stop chatbot processes
bash run.sh --stop-chatbot

# Show help
bash run.sh --help
```

## 🔄 Customization

### FAQ Database
Edit `ecommerce_chatbot/faq.csv` to customize frequently asked questions:
```csv
question,answer
How do I reset my password?,Click the "Forgot Password" link on the login page and follow the instructions.
```

### Product Templates
- `product.ejs`: Basic product page template
- `product_with_chatbot.ejs`: Product page with integrated chatbot

### Chatbot Behavior
Modify `ecommerce_chatbot/woocommerce_bot.py` to customize bot interactions.

## 🚀 Next Steps

1. **SSL Certificate**: Set up HTTPS with Let's Encrypt
2. **CDN Integration**: Configure CloudFlare or similar
3. **Monitoring**: Set up uptime monitoring
4. **Backup**: Configure automated backups
5. **SEO**: Submit sitemap to search engines
6. **Analytics**: Add Google Analytics or similar

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.

---

That's it! 🚀 You now have a high-performance static product page generator with an intelligent AI chatbot assistant.