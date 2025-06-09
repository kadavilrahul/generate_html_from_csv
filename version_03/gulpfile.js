const gulp = require('gulp');
const csv = require('csvtojson');
const fs = require('fs');
const path = require('path');
const ejs = require('ejs');
const axios = require('axios');
const xml2js = require('xml2js');

const csvFilePath = './products.csv'; // Relative to gulpfile.js
let outputDir = './public/products'; // Output directory
let imagesDir = './public/images'; // Images directory
const templatePath = './product.ejs'; // Relative to gulpfile.js
let baseUrl = 'https://your_website.com'; // Replace with your base URL
const dataDir = './data';

// Ensure the output directory exists
function ensureOutputDir(folderLocation, cb) {
  outputDir = path.join(folderLocation, 'public', 'products');
  imagesDir = path.join(folderLocation, 'public', 'images');
  baseUrl = `https://${folderLocation.split('/').pop()}`;

  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
    console.log(`Created output directory: ${outputDir}`);
  } else {
    console.log(`Output directory already exists: ${outputDir}`);
  }

  if (!fs.existsSync(imagesDir)) {
    fs.mkdirSync(imagesDir, { recursive: true });
    console.log(`Created images directory: ${imagesDir}`);
  } else {
    console.log(`Images directory already exists: ${imagesDir}`);
  }

  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
    console.log(`Created data directory: ${dataDir}`);
  } else {
    console.log(`Data directory already exists: ${dataDir}`);
  }
  cb();
}

// Function to sanitize filename
function sanitizeFilename(filename) {
    return filename.toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/(^-|-$)/g, '');
}

// Function to download image
async function downloadImage(url, filepath) {
  try {
      const response = await axios({
          url,
          responseType: 'stream'
      });
      return new Promise((resolve, reject) => {
          response.data.pipe(fs.createWriteStream(filepath))
              .on('finish', resolve)
              .on('error', reject);
      });
  } catch (error) {
      console.error(`Error downloading image from ${url}:`, error);
      throw error;
  }
}

// Function to generate products CSV
async function generateProductsCSV(products) {
  const csvHeader = 'title,price,product_link,category,image_url\n';
  const csvRows = products.map(product => {
    const title = `"${product.Title.replace(/"/g, '""')}"`;
    const price = product['Regular Price'];
    const productLink = `"${baseUrl}/public/products/${sanitizeFilename(product.Title)}.html"`;
    const category = `"${product.Category.replace(/"/g, '""')}"`;
    const imageUrl = `"${baseUrl}/public/images/${sanitizeFilename(product.Title)}${path.extname(product.Image) || '.jpg'}"`;
    
    return `${title},${price},${productLink},${category},${imageUrl}`;
  }).join('\n');

  const csvContent = csvHeader + csvRows;
  fs.writeFileSync(path.join(dataDir, 'products_database.csv'), csvContent);
  console.log('Products CSV generated successfully!');
}

// Function to generate sitemap
async function generateSitemap(products) {
  const sitemapContent = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url>
        <loc>${baseUrl}</loc>
        <lastmod>${new Date().toISOString()}</lastmod>
        <priority>1.0</priority>
    </url>
    ${products.map(product => `
    <url>
        <loc>${baseUrl}/public/products/${sanitizeFilename(product.Title)}.html</loc>
        <lastmod>${new Date().toISOString()}</lastmod>
        <priority>0.8</priority>
    </url>
    `).join('')}
</urlset>`;

  fs.writeFileSync(path.join(dataDir, 'sitemap.xml'), sitemapContent);
  console.log('Sitemap generated successfully!');
}

function csvToHtml(folderLocation, cb) {
  csv()
    .fromFile(csvFilePath)
    .then(async (jsonObj) => {
      ensureOutputDir(folderLocation, cb);
      for (const product of jsonObj) {
        try {
          // Generate image filename from title
          const imageExt = path.extname(product.Image) || '.jpg';
          const imageName = `${sanitizeFilename(product.Title)}${imageExt}`;
          const imagePath = path.join(imagesDir, imageName);
          const relativeImagePath = `/public/images/${imageName}`;

          // Download image
          await downloadImage(product.Image, imagePath);
          console.log(`Downloaded image: ${imagePath}`);

          // Prepare data for template
          const templateData = {
              title: product.Title,
              image: relativeImagePath,
              price: product['Regular Price'],
              category: product.Category,
              shortDescription: product.Short_description,
              description: product.description
          };

          // Generate HTML using EJS template
          const template = fs.readFileSync(templatePath, 'utf8');
          const htmlContent = ejs.render(template, templateData);

          // Save HTML file
          const htmlFilename = `${sanitizeFilename(product.Title)}.html`;
          const htmlPath = path.join(outputDir, htmlFilename);
          fs.writeFileSync(htmlPath, htmlContent);

          console.log(`Generated: ${htmlFilename}`);
        } catch (error) {
          console.error(`Error processing row for ${product.Title}:`, error);
        }
      }

      // Generate sitemap and products CSV
      await generateSitemap(jsonObj);
      await generateProductsCSV(jsonObj);

      console.log('CSV to HTML conversion complete.');
      cb(); // Signal completion of the async task
    })
    .catch((err) => {
      console.error('Error during CSV to HTML conversion:', err);
      cb(err); // Signal error
    });
}

gulp.task('default', (cb) => {
  let folderLocation = '';
  process.argv.slice(2).forEach(arg => {
    if (arg.startsWith('--folderLocation=')) {
      folderLocation = arg.split('=')[1];
    }
  });
  folderLocation = folderLocation || '/var/www/test.silkroademart.com';
  gulp.series((done) => ensureOutputDir(folderLocation, done), (done) => csvToHtml(folderLocation, done))(cb);
});
