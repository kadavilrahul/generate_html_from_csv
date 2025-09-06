# Static WooCommerce Product Pages Generator with AI Chatbot

Convert CSV product data into high-performance static HTML pages with an intelligent AI chatbot assistant.

## 🚀 Quick Start

### Installation

1. **Clone the repository:**

   ```bash
   git clone https://github.com/kadavilrahul/generate_html_from_csv.git
   ```

   ```bash
   cd generate_html_from_csv
   ```

   ```bash
   bash run.sh
   ```

3. **Follow the menu prompts:**
   - Choose "Full Setup & Generation" 
   - Enter your domain and folder location
   - Configure database settings
   - Optionally enable chatbot

4. **Configure chatbot (if enabled):**
   ```bash
   nano ecommerce_chatbot/.env
   ```
   Fill in: `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `WC_URL`, `GEMINI_API_KEY`

## ✨ Features

### 📄 Static Page Generator
- **Fast**: Serves pages directly via Apache (5-10x faster than WordPress)
- **SEO-friendly**: Clean URLs without file extensions
- **Incremental**: Only processes changed products
- **Auto-images**: Downloads and optimizes product images

### 🤖 AI Chatbot Assistant
- **Order tracking**: Check status using email or order ID
- **Product search**: Find products in your catalog
- **FAQ support**: Answer customer questions automatically
- **Easy integration**: REST API for any website

## 🛠️ Technology Stack

- **Backend**: Node.js, Gulp, EJS
- **AI Chatbot**: Python, Flask, Google Gemini AI
- **Database**: PostgreSQL (products), MySQL (WooCommerce)
- **Web Server**: Apache2 with mod_rewrite

## 📋 Requirements

- Ubuntu/Debian server
- Node.js and npm
- Python 3.12+
- Apache2, PostgreSQL, MySQL
- Root access

## 🎯 Usage Commands

```bash
# Interactive mode (default)
./run.sh

# Non-interactive mode (original behavior)
./run.sh --non-interactive

# Force regeneration of all products
./run.sh --force

# Enable chatbot automatically
./run.sh --enable-chatbot

# Check environment configuration
./run.sh --check-env

# Stop chatbot processes
./run.sh --stop-chatbot

# Show help
./run.sh --help
```

## 📁 CSV Format

Your `products.csv` should have these columns:
```csv
Image,Title,Regular Price,Category,Short_description,description
```

## 🌐 Generated Structure

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

**URLs:**
- WordPress: `yourdomain.com/`
- Products: `yourdomain.com/products/product-name`
- Images: `yourdomain.com/images/image-name.jpg`

## 🧪 Testing

### Test Static Pages
```bash
curl -I http://yourdomain.com/products/your-product-name
```

### Test Chatbot
```bash
curl "http://yourdomain.com/chatbot_proxy.php?input=hello"
```

## 🚀 Performance Benefits

| Metric | WordPress | Static Pages |
|--------|-----------|-------------|
| Load Time | 2-5 seconds | 0.2-0.5 seconds |
| Database Queries | Multiple per request | Zero |
| Server Resources | High | Minimal |

## 🛠️ Troubleshooting

### Common Issues

**403 Forbidden:**
```bash
sudo chown -R www-data:www-data /var/www/yourdomain.com/public
sudo chmod -R 755 /var/www/yourdomain.com/public
```

**mod_rewrite not working:**
```bash
sudo a2enmod rewrite
sudo systemctl restart apache2
```

**Chatbot not responding:**
```bash
# Check if Flask is running
ps aux | grep "python.*app.py"

# Check configuration
cat ecommerce_chatbot/chatbot_config.txt
```

### Log Files
- Apache Error: `/var/log/apache2/error_yourdomain.com.log`
- Chatbot: `ecommerce_chatbot/flask_app.log`

## 🔒 Security Features

- ✅ Directory browsing disabled
- ✅ CSV files blocked from direct access
- ✅ Proper file permissions
- ✅ Environment variables secured
- ✅ CORS properly configured

## 📱 Chatbot Integration

Add this to your HTML pages:

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

## 🔄 Customization

### FAQ Database
Edit `ecommerce_chatbot/faq.csv`:
```csv
question,answer
How do I reset my password?,Click "Forgot Password" and follow instructions.
```

### Product Templates
- `product.ejs`: Basic product page
- `product_with_chatbot.ejs`: Product page with chatbot

## 🚀 Next Steps

1. **SSL Certificate**: Set up HTTPS with Let's Encrypt
2. **CDN**: Configure CloudFlare or similar
3. **Monitoring**: Set up uptime monitoring
4. **Analytics**: Add Google Analytics

## 📦 Repository

### Clone the Project
```bash
# HTTPS
git clone https://github.com/kadavilrahul/generate_html_from_csv.git

# SSH
git clone git@github.com:kadavilrahul/generate_html_from_csv.git
```

### Contributing
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### License
This project is licensed under the MIT License - see the LICENSE file for details.

---

**That's it! 🚀 You now have high-performance static product pages with an intelligent AI chatbot.**