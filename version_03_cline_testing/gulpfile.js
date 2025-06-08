const gulp = require('gulp');
const csv = require('csvtojson');
const fs = require('fs');
const path = require('path');
const ejs = require('ejs');

const csvFilePath = './products.csv'; // Relative to gulpfile.js
const outputDir = '/var/www/test.silkroademart.com';
const templatePath = './product.ejs'; // Relative to gulpfile.js

// Ensure the output directory exists
function ensureOutputDir(cb) {
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
    console.log(`Created output directory: ${outputDir}`);
  } else {
    console.log(`Output directory already exists: ${outputDir}`);
  }
  cb();
}

// Function to sanitize filename
function sanitizeFilename(filename) {
    return filename.toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/(^-|-$)/g, '');
}

function csvToHtml(cb) {
  const template = fs.readFileSync(templatePath, 'utf8');

  csv()
    .fromFile(csvFilePath)
    .then((jsonObj) => {
      jsonObj.forEach((product) => {
        // Prepare data for template, mapping CSV headers to EJS variables
        const templateData = {
            title: product.Title,
            image: product.Image, // Assuming Image column contains the URL or path
            price: product['Regular Price'],
            category: product.Category,
            shortDescription: product.Short_description,
            description: product.description
        };

        const htmlContent = ejs.render(template, templateData);
        const fileName = `${sanitizeFilename(product.Title)}.html`;
        const outputPath = path.join(outputDir, fileName);
        fs.writeFileSync(outputPath, htmlContent);
        console.log(`Generated ${outputPath}`);
      });
      console.log('CSV to HTML conversion complete.');
      cb(); // Signal completion of the async task
    })
    .catch((err) => {
      console.error('Error during CSV to HTML conversion:', err);
      cb(err); // Signal error
    });
}

exports.csvToHtml = gulp.series(ensureOutputDir, csvToHtml);
