const gulp = require('gulp');
const csv = require('csvtojson');
const fs = require('fs');
const path = require('path');
const ejs = require('ejs');
const axios = require('axios');
const xml2js = require('xml2js');
const readline = require('readline');
const { Client } = require('pg');

let csvFilePath = './products.csv'; // Default CSV file, can be changed
let outputDir = './public/products'; // Output directory
let imagesDir = './public/images'; // Images directory
const templatePath = './product.ejs'; // Relative to gulpfile.js
let baseUrl = 'https://your_website.com'; // Replace with your base URL
const dataDir = './data';
const cacheFilePath = path.join(dataDir, 'generation_cache.json');

// Database configuration
let dbConfig = {
  host: 'localhost',
  port: 5432,
  database: null, // Will be set based on domain
  user: null,     // Will be set based on domain
  password: null  // Will be set based on domain
};

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
async function generateProductsCSV(products, sourceFileName) {
  const csvHeader = 'title,price,product_link,category,image_url\n';
  const csvRows = products.map(product => {
    const title = `"${product.Title.replace(/"/g, '""')}"`;
    const price = product['Regular Price'];
    const productLink = `"${baseUrl}/public/products/${sanitizeFilename(product.Title)}"`;
    const category = `"${product.Category.replace(/"/g, '""')}"`;
    const imageUrl = `"${baseUrl}/public/images/${sanitizeFilename(product.Title)}${path.extname(product.Image) || '.jpg'}"`;
    
    return `${title},${price},${productLink},${category},${imageUrl}`;
  }).join('\n');

  const csvContent = csvHeader + csvRows;
  
  // Generate filename based on source CSV file
  const baseName = path.basename(sourceFileName, path.extname(sourceFileName));
  const outputFilename = `${baseName}_database.csv`;
  
  fs.writeFileSync(path.join(dataDir, outputFilename), csvContent);
  console.log(`Products CSV generated successfully: ${outputFilename}`);
}

// Function to generate sitemap
async function generateSitemap(products, sourceFileName) {
  const sitemapContent = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url>
        <loc>${baseUrl}</loc>
        <lastmod>${new Date().toISOString()}</lastmod>
        <priority>1.0</priority>
    </url>
    ${products.map(product => `
    <url>
        <loc>${baseUrl}/public/products/${sanitizeFilename(product.Title)}</loc>
        <lastmod>${new Date().toISOString()}</lastmod>
        <priority>0.8</priority>
    </url>
    `).join('')}
</urlset>`;

  // Generate filename based on source CSV file
  const baseName = path.basename(sourceFileName, path.extname(sourceFileName));
  const outputFilename = `${baseName}_sitemap.xml`;

  fs.writeFileSync(path.join(dataDir, outputFilename), sitemapContent);
  console.log(`Sitemap generated successfully: ${outputFilename}`);
}

// Function to sanitize domain to valid database name
function sanitizeDbName(domain) {
  // Replace dots and hyphens with underscores and convert to lowercase
  return domain.replace(/[.-]/g, '_').toLowerCase();
}

// Function to load database credentials from config file
function loadDbCredentials(folderLocation) {
  const domain = folderLocation.split('/').pop();
  const domainCredentialsFile = `./data/${domain}_database_credentials.conf`;
  const legacyCredentialsFile = './database_credentials.conf';
  
  // Try domain-specific credentials file first
  let credentialsFile = domainCredentialsFile;
  if (!fs.existsSync(credentialsFile)) {
    // Fall back to legacy credentials file
    credentialsFile = legacyCredentialsFile;
    if (!fs.existsSync(credentialsFile)) {
      console.log('Database credentials file not found. Database operations will be skipped.');
      console.log('Run the database setup first to create credentials.');
      console.log(`Looked for: ${domainCredentialsFile} and ${legacyCredentialsFile}`);
      return null;
    }
  }

  try {
    const credentialsContent = fs.readFileSync(credentialsFile, 'utf8');
    
    // Parse credentials for the specific domain
    const lines = credentialsContent.split('\n');
    let currentDomain = null;
    let credentials = null;
    
    for (const line of lines) {
      if (line.startsWith('Domain: ')) {
        currentDomain = line.replace('Domain: ', '').trim();
      } else if (currentDomain === domain) {
        if (line.startsWith('Database: ')) {
          credentials = credentials || {};
          credentials.database = line.replace('Database: ', '').trim();
        } else if (line.startsWith('Username: ')) {
          credentials = credentials || {};
          credentials.user = line.replace('Username: ', '').trim();
        } else if (line.startsWith('Password: ')) {
          credentials = credentials || {};
          credentials.password = line.replace('Password: ', '').trim();
        }
      }
    }
    
    if (credentials && credentials.database && credentials.user && credentials.password) {
      return {
        host: 'localhost',
        port: 5432,
        database: credentials.database,
        user: credentials.user,
        password: credentials.password
      };
    }
    
    console.log(`Database credentials not found for domain: ${domain}`);
    return null;
  } catch (error) {
    console.error('Error reading database credentials:', error);
    return null;
  }
}

// Function to test database connection
async function testDbConnection(config) {
  const client = new Client(config);
  try {
    await client.connect();
    await client.query('SELECT NOW()');
    await client.end();
    return true;
  } catch (error) {
    console.error('Database connection test failed:', error.message);
    return false;
  }
}

// Function to create products table if it doesn't exist
async function createProductsTable(config) {
  const client = new Client(config);
  try {
    await client.connect();
    
    const createTableQuery = `
      CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255),
        price INTEGER,
        product_link TEXT,
        category VARCHAR(100),
        image_url TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      
      CREATE INDEX IF NOT EXISTS idx_products_title ON products(title);
      CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
    `;
    
    await client.query(createTableQuery);
    console.log('Products table created/verified successfully');
    
    await client.end();
    return true;
  } catch (error) {
    console.error('Error creating products table:', error);
    return false;
  }
}

// Function to clear existing products (for full regeneration)
async function clearProducts(config) {
  const client = new Client(config);
  try {
    await client.connect();
    await client.query('DELETE FROM products');
    console.log('Existing products cleared from database');
    await client.end();
    return true;
  } catch (error) {
    console.error('Error clearing products:', error);
    return false;
  }
}

// Function to insert products into database
async function insertProducts(config, products) {
  const client = new Client(config);
  try {
    await client.connect();
    
    let insertedCount = 0;
    let updatedCount = 0;
    
    for (const product of products) {
      const title = product.Title;
      const price = parseInt(product['Regular Price']) || 0;
      const productLink = `${baseUrl}/public/products/${sanitizeFilename(product.Title)}`;
      const category = product.Category;
      const imageExt = path.extname(product.Image) || '.jpg';
      const imageUrl = `${baseUrl}/public/images/${sanitizeFilename(product.Title)}${imageExt}`;
      
      // Check if product already exists
      const checkQuery = 'SELECT id FROM products WHERE title = $1';
      const checkResult = await client.query(checkQuery, [title]);
      
      if (checkResult.rows.length > 0) {
        // Update existing product
        const updateQuery = `
          UPDATE products 
          SET price = $2, product_link = $3, category = $4, image_url = $5, updated_at = CURRENT_TIMESTAMP
          WHERE title = $1
        `;
        await client.query(updateQuery, [title, price, productLink, category, imageUrl]);
        updatedCount++;
      } else {
        // Insert new product
        const insertQuery = `
          INSERT INTO products (title, price, product_link, category, image_url)
          VALUES ($1, $2, $3, $4, $5)
        `;
        await client.query(insertQuery, [title, price, productLink, category, imageUrl]);
        insertedCount++;
      }
    }
    
    console.log(`Database updated: ${insertedCount} products inserted, ${updatedCount} products updated`);
    
    await client.end();
    return { inserted: insertedCount, updated: updatedCount };
  } catch (error) {
    console.error('Error inserting products into database:', error);
    return null;
  }
}

// Function to create or update database
async function createOrUpdateDatabase(products, sourceFileName, folderLocation) {
  console.log('\n=== Database Operations ===');
  
  // Load database credentials
  const dbCredentials = loadDbCredentials(folderLocation);
  if (!dbCredentials) {
    console.log('Skipping database operations - no credentials found');
    return;
  }
  
  console.log(`Connecting to database: ${dbCredentials.database}`);
  
  // Test database connection
  const connectionTest = await testDbConnection(dbCredentials);
  if (!connectionTest) {
    console.log('Skipping database operations - connection failed');
    return;
  }
  
  // Create products table if it doesn't exist
  const tableCreated = await createProductsTable(dbCredentials);
  if (!tableCreated) {
    console.log('Skipping database operations - table creation failed');
    return;
  }
  
  // Ask user if they want to clear existing products (for full regeneration)
  if (forceRegeneration) {
    console.log('Force regeneration enabled - clearing existing products');
    await clearProducts(dbCredentials);
  }
  
  // Insert/update products
  const result = await insertProducts(dbCredentials, products);
  if (result) {
    console.log('Database operations completed successfully');
    
    // Generate database summary
    const baseName = path.basename(sourceFileName, path.extname(sourceFileName));
    const summaryFile = path.join(dataDir, `${baseName}_database_summary.txt`);
    const summaryContent = `Database Update Summary
Generated: ${new Date().toISOString()}
Database: ${dbCredentials.database}
Products Inserted: ${result.inserted}
Products Updated: ${result.updated}
Total Products: ${result.inserted + result.updated}
Source File: ${sourceFileName}
`;
    
    fs.writeFileSync(summaryFile, summaryContent);
    console.log(`Database summary saved: ${baseName}_database_summary.txt`);
  }
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
      await generateSitemap(jsonObj, selectedCsvPath);
      await generateProductsCSV(jsonObj, selectedCsvPath);
      
      // Create or update database
      await createOrUpdateDatabase(jsonObj, selectedCsvPath, folderLocation);

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
    if (arg === '--force') {
      forceRegeneration = true;
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
