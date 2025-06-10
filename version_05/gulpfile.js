const gulp = require('gulp');
const csv = require('csvtojson');
const fs = require('fs');
const path = require('path');
const ejs = require('ejs');
const axios = require('axios');
const xml2js = require('xml2js');
const readline = require('readline');

let csvFilePath = './products.csv'; // Default CSV file, can be changed
let outputDir = './public/products'; // Output directory
let imagesDir = './public/images'; // Images directory
const templatePath = './product.ejs'; // Relative to gulpfile.js
let baseUrl = 'https://your_website.com'; // Replace with your base URL
const dataDir = './data';
const cacheFilePath = path.join(dataDir, 'generation_cache.json');

// Global variables for incremental processing
let forceRegeneration = false;
let csvModifiedTime = null;

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

// Function to list and select CSV files
async function selectCSVFile() {
  return new Promise((resolve, reject) => {
    // Get all CSV files in the current directory
    const csvFiles = fs.readdirSync('.').filter(file => 
      file.toLowerCase().endsWith('.csv') && fs.statSync(file).isFile()
    );

    if (csvFiles.length === 0) {
      console.log('No CSV files found in the current directory.');
      resolve('./products.csv'); // Default fallback
      return;
    }

    console.log('\nAvailable CSV files:');
    csvFiles.forEach((file, index) => {
      const stats = fs.statSync(file);
      const modifiedDate = stats.mtime.toISOString().split('T')[0];
      const size = (stats.size / 1024).toFixed(2);
      console.log(`${index + 1}. ${file} (Modified: ${modifiedDate}, Size: ${size} KB)`);
    });

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    rl.question('\nEnter the number of the CSV file to use (or press Enter for default products.csv): ', (answer) => {
      rl.close();
      
      if (!answer.trim()) {
        console.log('Using default: products.csv');
        resolve('./products.csv');
        return;
      }

      const fileIndex = parseInt(answer) - 1;
      if (fileIndex >= 0 && fileIndex < csvFiles.length) {
        const selectedFile = `./${csvFiles[fileIndex]}`;
        console.log(`Selected CSV file: ${csvFiles[fileIndex]}`);
        resolve(selectedFile);
      } else {
        console.log('Invalid selection. Using default: products.csv');
        resolve('./products.csv');
      }
    });
  });
}

// Function to display usage help
function displayHelp() {
  console.log('\n=== Product Page Generator - CSV File Selection ===');
  console.log('Usage options:');
  console.log('1. Interactive mode: npm start (will show CSV file selection menu)');
  console.log('2. Command line mode: npm start -- --csvFile=your_file.csv --folderLocation=/path/to/output');
  console.log('\nExamples:');
  console.log('  npm start -- --csvFile=products_01.csv');
  console.log('  npm start -- --csvFile=products_backup.csv --folderLocation=/var/www/mysite.com');
  console.log('\nNote: If csvFile is not specified or not found, interactive selection menu will be shown.');
  console.log('======================================================\n');
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
  
  // Generate timestamp for filename
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').replace('T', '_').split('.')[0];
  const timestampedFilename = `products_database_${timestamp}.csv`;
  
  fs.writeFileSync(path.join(dataDir, timestampedFilename), csvContent);
  console.log(`Products CSV generated successfully: ${timestampedFilename}`);
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

  // Generate timestamp for filename
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').replace('T', '_').split('.')[0];
  const timestampedFilename = `sitemap_${timestamp}.xml`;

  fs.writeFileSync(path.join(dataDir, timestampedFilename), sitemapContent);
  console.log(`Sitemap generated successfully: ${timestampedFilename}`);
}

function csvToHtml(folderLocation, selectedCsvPath, cb) {
  csv()
    .fromFile(selectedCsvPath)
    .then(async (jsonObj) => {
      ensureOutputDir(folderLocation, () => {}); // Empty callback since we're handling async differently
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

gulp.task('default', async (cb) => {
  let folderLocation = '';
  let csvFileArg = '';
  let showHelp = false;
  
  process.argv.slice(2).forEach(arg => {
    if (arg.startsWith('--folderLocation=')) {
      folderLocation = arg.split('=')[1];
    }
    if (arg.startsWith('--csvFile=')) {
      csvFileArg = arg.split('=')[1];
    }
    if (arg === '--help' || arg === '-h') {
      showHelp = true;
    }
  });
  
  if (showHelp) {
    displayHelp();
    cb();
    return;
  }
  
  folderLocation = folderLocation || '/var/www/test.silkroademart.com';
  
  try {
    let selectedCsvPath;
    
    // If CSV file specified via command line, use it
    if (csvFileArg) {
      if (fs.existsSync(csvFileArg)) {
        selectedCsvPath = csvFileArg;
        console.log(`Using CSV file from command line: ${csvFileArg}`);
      } else {
        console.log(`CSV file not found: ${csvFileArg}. Falling back to selection menu.`);
        selectedCsvPath = await selectCSVFile();
      }
    } else {
      // Otherwise, show selection menu
      selectedCsvPath = await selectCSVFile();
    }
    
    // Run the tasks with the selected CSV file
    gulp.series(
      (done) => ensureOutputDir(folderLocation, done), 
      (done) => csvToHtml(folderLocation, selectedCsvPath, done)
    )(cb);
  } catch (error) {
    console.error('Error in task execution:', error);
    cb(error);
  }
});
