# Static WooCommerce Product Pages Generator

A complete solution that converts CSV product data into static HTML pages served directly by Apache, bypassing WordPress for better performance while maintaining WordPress admin functionality.

## What it does

- **CSV to HTML**: Converts product data into individual HTML pages
- **Static Serving**: Serves pages directly via Apache (faster than WordPress)
- **Clean URLs**: SEO-friendly URLs without file extensions (`/products/product-name`)
- **Auto Images**: Downloads and optimizes product images automatically
- **Incremental**: Only processes changed products for efficiency
- **WordPress Compatible**: Maintains WordPress backend for admin/management

## Quick Setup

### Prerequisites
- Ubuntu/Debian server with Apache2 installed
- Root access
- Domain pointing to your server (optional for testing)
- Node.js and npm

### Installation Steps


1. **Generate your product pages:**
   ```bash
   bash run_min.sh
   ```
   
   **Select to run setup script to configure folders in apache:**

   **Follow the prompts:**
   - Enter your domain (e.g., `example.com`)
   - Enter website directory (e.g., `/var/www/example.com`)
   - Enter admin email


## What the Setup Script Does

### 🔧 **System Configuration**
- ✅ Checks Apache and enables mod_rewrite
- ✅ Creates directory structure (`/public/products/`, `/public/images/`)
- ✅ Sets proper file permissions

### 🌐 **Apache Configuration**
- ✅ Creates virtual host configuration
- ✅ Sets up URL aliases (`/products/` → `/public/products/`)
- ✅ Enables clean URLs (no `.html` extension)
- ✅ Configures basic caching

### 📁 **File Structure Created**
```
/var/www/yourdomain.com/
├── [WordPress files]           # Your existing WordPress
├── public/
│   ├── products/              # Generated HTML files
│   │   └── .htaccess         # URL rewriting rules
│   └── images/               # Product images
```

### 🔗 **URL Structure**
- **WordPress**: `yourdomain.com/` (admin, other pages)
- **Static Products**: `yourdomain.com/products/product-name`
- **Product Images**: `yourdomain.com/images/image-name.jpg`

## Files you need

- `products.csv` - Your product data
- `product.ejs` - HTML template for product pages

## What gets generated

- **HTML pages** → `your-folder/public/products/`
- **Product images** → `your-folder/public/images/`
- **Sitemap** → `./data/sitemap.xml`
- **Products database** → `./data/products_database.csv`

## CSV Format

Your `products.csv` should have these columns:
```
Image,Title,Regular Price,Category,Short_description,description
```

## Generation Modes

- **Incremental** (default): Only processes new/changed products
- **Force**: Regenerates all products regardless of changes

## Testing Your Setup

### 1. **Generate Products**
```bash
./run.sh
# Follow prompts to generate HTML pages from CSV
```

### 2. **Test Static File Serving**
```bash
# Should return 200 OK after generating products
curl -I http://yourdomain.com/products/your-product-name
```

### 3. **Test Clean URLs**
```bash
# Both should work:
curl http://yourdomain.com/products/product-name
curl http://yourdomain.com/products/product-name.html
```

## Troubleshooting

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

**3. "Site not loading"**
```bash
# Check Apache configuration
apache2ctl configtest
systemctl status apache2
```

### Log Files
- **Apache Error Log**: `/var/log/apache2/error_yourdomain.com.log`
- **Apache Access Log**: `/var/log/apache2/access_yourdomain.com.log`

```bash
# Monitor logs in real-time
tail -f /var/log/apache2/error_yourdomain.com.log
```

## Performance Benefits

### Before (WordPress)
- ⏱️ 2-5 seconds page load time
- 🔄 Database queries for each request
- 💾 High server resource usage

### After (Static Pages)
- ⚡ 0.2-0.5 seconds page load time
- 🚀 Direct file serving by Apache
- 💡 Minimal server resource usage

## Security Features

- ✅ Directory browsing disabled
- ✅ CSV files blocked from direct access
- ✅ Proper file permissions set
- ✅ Separate static content from WordPress core

## Next Steps

1. **SSL Certificate**: Set up HTTPS with Let's Encrypt
2. **CDN Integration**: Configure CloudFlare or similar
3. **Monitoring**: Set up uptime monitoring
4. **Backup**: Configure automated backups
5. **SEO**: Submit sitemap to search engines

That's it! 🚀