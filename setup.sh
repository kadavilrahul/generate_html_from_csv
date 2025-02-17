#!/bin/bash

# Exit on any error
set -e

echo "Starting setup process..."

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Installing jq..."
    sudo apt-get update && sudo apt-get install -y jq
fi

# Get configuration values from config.json
PROJECT_DIR=$(jq -r '.project.directory' config.json)
BASE_URL=$(jq -r '.project.baseUrl' config.json)
DB_HOST=$(jq -r '.database.host' config.json)
DB_USER=$(jq -r '.database.username' config.json)
DB_PASS=$(jq -r '.database.password' config.json)
DB_NAME=$(jq -r '.database.name' config.json)
API_URL=$(jq -r '.api.url' config.json)
API_KEY=$(jq -r '.api.consumerKey' config.json)
API_SECRET=$(jq -r '.api.consumerSecret' config.json)
FAVICON_URL=$(jq -r '.branding.faviconUrl' config.json)

# Function to move files to correct locations
move_project_files() {
    echo "Moving project files to correct locations..."
    
    # Move search.php to public/products if it exists
    if [ -f "$PROJECT_DIR/search.php" ]; then
        echo "Moving search.php to public/products directory..."
        mv "$PROJECT_DIR/search.php" "$PROJECT_DIR/public/products/"
        echo "search.php moved successfully"
    else
        echo "Warning: search.php not found in project root directory"
    fi

    # Move products.csv to data directory if it exists
    if [ -f "$PROJECT_DIR/products.csv" ]; then
        echo "Moving products.csv to data directory..."
        mv "$PROJECT_DIR/products.csv" "$PROJECT_DIR/data/"
        echo "products.csv moved successfully"
    else
        echo "Warning: products.csv not found in project root directory"
    fi
}

# Create project structure
echo "Creating directory structure..."
sudo mkdir -p "$PROJECT_DIR"/{data,views,public/{products,images}}

# Set proper permissions
echo "Setting permissions..."
sudo chown -R "$USER:$USER" "$PROJECT_DIR"
sudo chmod -R 755 "$PROJECT_DIR"

# Navigate to project directory
cd "$PROJECT_DIR"

# Initialize Node.js project and install dependencies
echo "Initializing Node.js project..."
npm init -y

echo "Installing dependencies..."
npm install csv-parser ejs axios @json2csv/node

# Create EJS template with injected configuration
echo "Creating EJS template..."
cat > views/product.ejs << EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= title %></title>
    <link rel="icon" type="image/x-icon" href="${FAVICON_URL}">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.7.1/css/all.min.css" integrity="sha512-5Hs3dF2AEPkpNAR7UiOHba+lRSJNeM2ECkwxUIxC1Q/FLycGTbNapWXB4tP889k5T5Ju8fs4b1P5z/iB4nMfSQ==" crossorigin="anonymous" referrerpolicy="no-referrer" />
    <style>
        .loading-spinner {
            display: none;
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            z-index: 1002;
        }
        .success-message, .error-message {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 15px;
            border-radius: 4px;
            display: none;
            z-index: 1001;
            color: white;
        }
        .success-message {
            background-color: #4CAF50;
        }
        .error-message {
            background-color: #f44336;
        }

        body{
        background-color: rgb(237, 237, 237);
    }
    #logo {
        width: 200px;
    }

    .logo-left .logo {
        margin-left: 0;
        margin-right: 30px;
    }

    .logo {
        line-height: 1;
        margin: 0;
    }

    .flex-col {
        max-height: 100%;
    }

    .logo a {
        color: var(--fs-color-primary);
        display: block;
        font-size: 32px;
        font-weight: bolder;
        margin: 0;
        text-decoration: none;
        text-transform: uppercase;
    }

    #logo img {
        max-height: 90px;
    }

    .logo img {
        display: block;
        width: auto;
    }

    img {
        opacity: 1;
        transition: opacity 1s;
    }

    img {
        display: inline-block;
        height: auto;
        max-width: 100%;
        vertical-align: middle;
    }

    img {
        overflow-clip-margin: content-box;
        overflow: clip;
    }

    ul {
        color: grey;
    }

    .nav-item a {
        color: grey !important;
        text-transform: uppercase;
        font-weight: 700;
        font-size: 12.8px;
    }

    .login a {
        text-decoration: none;
        color: grey;
        font-weight: 700;
        font-size: 12.8px;
        border-right: 1px solid grey;
        padding-right: 10px;
    }
    .checkout{
        margin-left: 8px;
    }
    .checkout a{
        font-size: .8em;
        text-transform: uppercase;
        text-decoration: none;
        border-radius: 20px;
    }
    .circle, .circle img {
    border-radius: 999px !important;
    -o-object-fit: cover;
    object-fit: cover;
}
.button.alt, .button.checkout, .checkout-button, .secondary {
    background-color: #4b9cd2;
    color: #fff;
}
.button, button, input[type=button], input[type=reset], input[type=submit] {
    
    border: 1px solid #fff0;
    border-radius: 0;
    box-sizing: border-box;
 
    cursor: pointer;
    display: inline-block;
    font-size: .97em;
    font-weight: bolder;
    letter-spacing: .03em;
    line-height: 2.4em;
    margin-right: 1em;
    margin-top: 0;
    max-width: 100%;
    min-height: 2.5em;
    padding: 0 1.2em;
    position: relative;
    text-align: center;
    text-decoration: none;
    text-rendering: optimizeLegibility;
    text-shadow: none;
    text-transform: uppercase;
    transition: transform .3s, border .3s, background .3s, box-shadow .3s, opacity .3s, color .3s;
    vertical-align: middle;
}
.header-cart-link{
    text-decoration: none;
    text-transform: uppercase;
    color: grey;
    font-size: 12.8px;
    font-weight: 700;
}
.cart-icon strong {
    border: 2px solid black;
    border-radius: 0;
    color: var(--fs-color-primary);
    font-family: Helvetica, Arial, Sans-serif;
    font-size: 1em;
    font-weight: 700;
    height: 2.2em;
    line-height: 1.9em;
    margin: .3em 0;
    position: relative;
    text-align: center;
    vertical-align: middle;
    width: 2.2em;
    display: inline-block;
}
.cart-icon strong:after {
    border: 2px solid black;
    border-bottom: 0;
    border-top-left-radius: 99px;
    border-top-right-radius: 99px;
    bottom: 100%;
    content: " ";
    height: 8px;
    left: 50%;
    margin-bottom: 0;
    margin-left: -7px;
    pointer-events: none;
    position: absolute;
    transition: height .1s ease-out;
    width: 14px;
}
.top-nav{
    height: 30px;
    background-color: #446084;
    
   
}
.top-items{
    float: right;
    padding-right: 90px;
}
.top-items span{
    color: white;
    font-size: 12.8px;
    font-weight: 400;
}
.search-input{
    width: 100%;
}
.search-section{
    padding-left: 270px;
}
.search-drop-down select{
    width: 100%;
    padding: 0;
    height: 100%;
}
.add-to-cart-section{
    background-color: white;
    text-align: center;
    padding-top: 20px;
    padding-bottom: 20px;
    border-radius: 20px;
    box-shadow: 0 3px 6px -4px rgb(0 0 0 / .16), 0 3px 6px rgb(0 0 0 / .23);
}
.number-input {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 72px;
            margin: 20px;
            border: 1px solid #ddd;
            border-radius: 99px;
            overflow: hidden;
            margin: 30px 90px;
        }

        .number-input button {
            background-color: #ddd;
            color: white;
            border: none;
            cursor: pointer;
            font-size: 16px;
            margin-right: 0;
            height: 40px; /* Match the input's height */
            padding: 4px 4px;
        }

        .number-input button:disabled {
            background-color: #ccc;
            cursor: not-allowed;
        }

        .number-input input[type="number"] {
            width: 37px;
            text-align: center;
            font-size: 16px;
            border: none;
            height: 40px; /* Match the button's height */
            background-color: #ccc;
        }

        .number-input button:first-child {
            border-right: 1px solid #ddd; /* Seamless border between button and input */
        }

        .number-input button:last-child {
            border-left: 1px solid #ddd; /* Seamless border between button and input */
        }
        .add-to-cart-button{
            background-color: #4b9cd2;
            color: white;
            border-radius: 20px;
        }
        .add-to-cart-section-bottom{
            background-color: white;
            border-radius: 20px;
            box-shadow: 0 3px 6px -4px rgb(0 0 0 / .16), 0 3px 6px rgb(0 0 0 / .23);
            padding: 30px;


        }
        .add-to-cart-section-bottom li{
            border-bottom: 1px solid grey;
            padding: 7px 0 7px 25px;
            font-size: 16px;
        }
        .Description-section{
            background-color: white;
            padding: 30px;
            border-radius: 20px;
        }
        .Description-section .description-toggle {
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: space-between;
}

.Description-section .arrow {
    display: inline-block;
    transition: transform 0.3s ease;
}

.Description-section .arrow.open {
    transform: rotate(180deg);
}

.Description-details {
    max-height: none; /* Full height by default */
    opacity: 1;       /* Fully visible by default */
    overflow: hidden;
    transition: max-height 0.3s ease, opacity 0.3s ease;
}

.Description-details.collapsed {
    max-height: 0;
    opacity: 0;
}
.description-toggle{
    font-size: 17.6px;
    font-weight: 400;
    color:#777777
}
.Description-details strong{
    font-size: 12.8px;
    font-weight: 700;
    text-transform: uppercase;
    color: #777777;
}
.top-footer{
    height: 40px;
    background-color: #777;
}
footer{
    background-color: #5b5b5b;
    display: flex;
    justify-content: space-between; /* Ensures both divs are at the ends of the line */
    align-items: center;
    padding-left: 30px;
    padding-right: 30px;
}
.footer .container {
    margin: 0; /* Removes any default margins */
}

.text-right {
    text-align: right;
}
.Copyright{
    color: #a5a4a4;
}
.payment-icons i{
    font-size: 40px;
    margin-right: 10px;

}
/* Style to highlight the selected thumbnail */
#thumbnailSlider img:hover {
    opacity: 0.7;
    transform: scale(1.1);
    transition: transform 0.3s ease, opacity 0.3s ease;
}

#thumbnailSlider img.active {
    border: 2px solid #007bff; /* Border color when active */
}
.logo-image{
    width:200px;
    height: 90px;
}

/* Adjust logo for mobile */
@media (max-width: 768px) {
    #logo {
        margin: 0 auto; /* Center the logo */
        text-align: center;
    }

    .navbar-toggler {
        position: absolute;
        left: 10px; /* Position menu button on the left */
    }

    .collapse.navbar-collapse {
        position: fixed;
        top: 0;
        left: -100%;
        height: 100%;
        width: 250px;
        background: #f8f9fa;
        z-index: 1050;
        overflow-y: auto;
        transition: left 0.3s ease-in-out;
    }

    .collapse.navbar-collapse.show {
        left: 0;
    }

    .navbar-nav {
        display: flex;
        flex-direction: column;
        padding: 1rem;
    }

    .nav-item {
        margin-bottom: 1rem;
    }
    #navbarContent {
    position: fixed; /* Keep the menu fixed */
    top: 0;
     /* Initially hide the menu off-screen */
    height: 100vh; /* Full height for the menu */
    width: 350px; /* Set the width of the sliding menu */
    background-color: white; /* Menu background color */
    z-index: 1050; /* Ensure it stays on top */
    transition: transform 0.3s ease-in-out; /* Smooth sliding animation */
    transform: translateX(-100%); /* Start off-screen */
}

#navbarContent.show {
    transform: translateX(0); /* Slide into view when shown */
}
.collapse .btn-close {
    position: absolute;
    top: 10px;
    right: 10px;
}
.search-section{
    padding-left: 50px;
    padding-top: 20px;
}
.m_search{
    margin-top: 100px;
}
.logo-image{
    width: 150px;
    height: 60px;
    margin-left: 30%;
}
.checkout-cart{
    display: none;
}
.login{
    margin-left: 18px;
}
.number-input{
    margin-left: 40%;
}




    
}

  </style>
</head>
<body>
    <header class="bg-light ">
        <div class="top-nav">
            <div class="top-items ">
                <span class="fa fa-envelope"></span>

                <span style="margin-right: 10px;">News Letter</span>
                <span class="fab fa-facebook-f"></span>
                <span class="fab fa-instagram"></span>
                <span class="fab fa-twitter"></span>
                <span class="fa fa-envelope"></span>



            </div>

        </div>
      
          
        <nav class="navbar navbar-expand-lg navbar-light bg-light">
            <div class="container">
                <!-- Toggler Button for Collapsible Navbar -->
                <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarContent" aria-controls="navbarContent" aria-expanded="false" aria-label="Toggle navigation">
                    <span class="navbar-toggler-icon"></span>
                </button>
    
                <!-- Logo -->
                <div id="logo" class="flex-col logo">
                    <a href="https://silkroademart.com/" title="Silk Road e-Mart">
                        <img class="logo-image"  src="https://i0.wp.com/silkroademart.com/wp-content/uploads/2024/09/Silkroademart-logo-7.png?fit=922%2C743&amp;ssl=1" alt="Silk Road e-Mart">
                    </a>
                </div>
    
                <!-- Collapsible Navbar Content -->
                <div class="collapse navbar-collapse" id="navbarContent">
                    <button class="btn-close text-reset d-lg-none ms-auto mb-3" aria-label="Close" onclick="toggleNavbar()"></button>

                    <div class="search-section row container d-lg-none m_search">
                        <form class="row" action="search.php">
                            <div class="search-drop-down col-2 col-lg-1 col-md-1" style="padding-right: 0;">
                                <select >
                                    <option>All</option>
                                </select>
                            </div>
                            <div class="search-input-section col-10 col-lg-11 col-md-11" style="padding-left: 0;display: flex;">
                                <input class="search-input" type="text" name="term" placeholder="Search Products">
                                <button type="submit" value="Search" class="ux-search-submit submit-button secondary button  icon mb-0" aria-label="Submit">
                                    <i class="fa fa-search"></i>			</button>
                
                            </div>
                        </form>
                        
                       
            
            
                    </div>
                    <ul class="navbar-nav me-auto mb-2 mb-lg-0">
                        <li class="nav-item"><a class="nav-link" href="https://silkroademart.com/shop//">Shop</a></li>
                        <li class="nav-item"><a class="nav-link" href="https://silkroademart.com/elements/product-categories/">Categories</a></li>
                        <li class="nav-item"><a class="nav-link" href="https://silkroademart.com/about/">About</a></li>
                        <li class="nav-item"><a class="nav-link" href="https://silkroademart.com/contact-us/">Contact</a></li>
                    </ul>
                    <div class="d-flex ms-auto">
                        <!-- Login Link -->
                        <div class="login me-3">
                            <a class="text-decoration-none text-secondary fw-bold" href="#">LOGIN</a>
                        </div>
                        <div class="checkout me-3">
                            <a class="button checkout-button" href="/cart/">Checkout</a>
                        </div>
                        <!-- Cart Link -->
                        <div class="checkout-cart">
                            <a href="#" class="header-cart-link text-secondary fw-bold">
                                <span class="header-cart-title">
                                    Cart / <span class="cart-price"><bdi>₹0</bdi></span>
                                </span>
                                <span class="cart-icon">
                                    <strong>0</strong>
                                </span>
                            </a>
                        </div>
                    </div>
                </div>
            </div>
        </nav>
        
    </header>
    <section>
        <div class="search-section row container">
            <form class="row" action="search.php">
                <div class="search-drop-down col-2 col-lg-1 col-md-1" style="padding-right: 0;">
                    <select >
                        <option>All</option>
                    </select>
                </div>
                <div class="search-input-section col-10 col-lg-11 col-md-11" style="padding-left: 0;display: flex;">
                    <input class="search-input" type="text" name="term" placeholder="Search Products">
                    <button type="submit" value="Search" class="ux-search-submit submit-button secondary button  icon mb-0" aria-label="Submit">
                        <i class="fa fa-search"></i>			</button>
    
                </div>
            </form>
            
           


        </div>
    </section>


    <main class="container my-5">
        <div class="row">
            <div class="col-md-6">
                <!-- Main Image -->
                <img id="mainImage" src="<%= image %>" alt="<%= title %>" class="img-fluid mb-3">
            
                <!-- Thumbnails -->
                <div class="d-flex" id="thumbnailSlider">
                    <img src="<%= image %>" alt="<%= title %>" class="img-thumbnail me-2" style="width: 80px; cursor: pointer;">
                    <img src="<%= image %>" alt="<%= title %>" class="img-thumbnail me-2" style="width: 80px; cursor: pointer;">
                    <img src="<%= image %>" alt="<%= title %>" class="img-thumbnail" style="width: 80px; cursor: pointer;">
                </div>
            </div>
            <div class="col-md-3">
                <h2><%= title %></h2>
                <p class="text-muted">Category: <%= category %></p>
                <p class="text-muted"><%= shortDescription %></p>
                
            </div>
            <div class="col-md-3 col-12 col-lg-3">

                <div class="add-to-cart-section">
                    <h3 >₹<%= price %></h3>
                    <p class="text-danger"> Shipping cost extra*</p>
                    <form id="orderForm" class="order-form">
                        <div class="number-input">
                            <button type="button" onclick="changeValue(-1)">−</button>
                            <input type="number" id="number" value="0" min="0" max="100" name="quantity">
                            <button type="button" onclick="changeValue(1)">+</button>
                        </div>
                    
                        <button type="submit" class="add-to-cart-button">Place order</button>
                    </form>
                    
                </div>
               
                

                <div class="mt-4 add-to-cart-section-bottom">
                    <ul class="list-unstyled">
                        <li><span>✔️</span> Guaranteed delivery</li>
                        <li><span>✔️</span> PAN India shipping</li>
                        <li><span>✔️</span> 100% Secure payment system</li>
                        <li><span>✔️</span> Dispatch Regular orders in 48 Hours</li>
                        <li><span>✔️</span> Dispatch Pre-orders in 30-45 days</li>
                        <li><span>✔️</span> Returns accepted. Fast refund</li>
                    </ul>
                </div>
            </div>
        </div>

        <section class="mt-5 Description-section">
            <div class="container">
                <div class="Description">
                    <h4 class="description-toggle">
                        Description
                        <span class="arrow open">▼</span>
                    </h4>
                </div>
                <div class="Description-details description">
                    <%= description %>
                </div>
            </div>
        </section>
        
        
    </main>
    <div class="top-footer">


    </div>

    <footer class="py-3 footer">
        <div class=" text-left Copyright">
            <p>Copyright 2024  Silk Road e-Mart</p>
        </div>
        <div class="text-right">
            <nav class="d-flex align-items-center flex-grow-1">
                <ul class="nav me-auto">
                    <li class="nav-item payment-icons"><i class="fab fa-cc-visa"></i></li>
                    <li class="nav-item payment-icons"><i class="fab fa-cc-paypal"></i></li>
                    <li class="nav-item payment-icons"><i class="fab fa-cc-stripe"></i></li>
                    <li class="nav-item payment-icons"><i class="fab fa-cc-mastercard"></i></li>
                    <li class="nav-item payment-icons"><i class="fab fa-cc-paytm"></i></li>

                </ul>
                </nav>
        </div>
    </footer>
    

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>

    <!-- Loading Spinner -->
  <div class="loading-spinner">
    <div class="spinner-border text-primary" role="status">
        <span class="visually-hidden">Loading...</span>
    </div>
</div>

<!-- Success/Error Messages -->
<div id="successMessage" class="success-message">Operation successful!</div>
<div id="errorMessage" class="error-message">An error occurred. Please try again.</div>

<script>
    const API_URL = "${API_URL}";
    const CREDENTIALS = btoa("${API_KEY}:${API_SECRET}");
    const BASE_URL = "${BASE_URL}";

    let createdProductId = null;

    function showSpinner() {
        document.querySelector('.loading-spinner').style.display = 'block';
    }

    function hideSpinner() {
        document.querySelector('.loading-spinner').style.display = 'none';
    }

    function showMessage(type, message) {
        const element = document.getElementById(`${type}Message`);
        element.textContent = message;
        element.style.display = 'block';
        setTimeout(() => {
            element.style.display = 'none';
        }, 3000);
    }

    async function createProduct() {
        const productData = {
            name: document.querySelector('h2').innerText,
            type: 'simple',
            regular_price: document.querySelector('h3').innerText.replace('₹', ''),
            description: document.querySelector('.description').innerText,
            short_description: document.querySelector('.text-muted:nth-of-type(2)').innerText,
            categories: [{
                name: document.querySelector('.text-muted:nth-of-type(1)').innerText.replace('Category: ', '')
            }],
            images: [{
                src: document.getElementById('mainImage').src
            }]
        };

        const response = await fetch(`${API_URL}/products`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Basic ${CREDENTIALS}`
            },
            body: JSON.stringify(productData)
        });

        if (!response.ok) throw new Error('Failed to create product');

        const data = await response.json();
        return data.id;
    }

    // Handle initial order form submission
    document.getElementById('orderForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        showSpinner();

        try {
            createdProductId = await createProduct();
            showMessage('success', 'Product added to cart successfully!');

            // Redirect to WooCommerce cart with the product added
            const quantity = document.querySelector('input[name="quantity"]').value;
            const cartUrl = `${BASE_URL}/cart/?add-to-cart=${createdProductId}&quantity=${quantity}`;
            window.location.href = cartUrl;
        } catch (error) {
            console.error('Error:', error);
            showMessage('error', 'Failed to create product');
        } finally {
            hideSpinner();
        }
    });
</script>

<script>
    document.addEventListener("DOMContentLoaded", function () {
        const toggle = document.querySelector(".description-toggle");
        const details = document.querySelector(".Description-details");
        const arrow = document.querySelector(".arrow");

        toggle.addEventListener("click", () => {
            const isCollapsed = details.classList.contains("collapsed");
            if (isCollapsed) {
                details.classList.remove("collapsed");
                details.style.maxHeight = details.scrollHeight + "px";
                details.style.opacity = "1";
            } else {
                details.classList.add("collapsed");
                details.style.maxHeight = "0";
                details.style.opacity = "0";
            }

            // Toggle arrow rotation
            arrow.classList.toggle("open");
        });
    });
</script>
<script>
    function changeValue(delta) {
        const input = document.getElementById('number');
        const min = parseInt(input.min) || -Infinity;
        const max = parseInt(input.max) || Infinity;
        const currentValue = parseInt(input.value) || 0;

        let newValue = currentValue + delta;
        if (newValue >= min && newValue <= max) {
            input.value = newValue;
        }
    }
</script>

<script>
    // Get all thumbnail images and the main image
const thumbnails = document.querySelectorAll('#thumbnailSlider img');
const mainImage = document.getElementById('mainImage');

// Loop through thumbnails and add hover event
thumbnails.forEach(thumbnail => {
    thumbnail.addEventListener('mouseenter', function() {
        // Change the main image to the one clicked on
        mainImage.src = this.src;

        // Remove the 'active' class from all thumbnails
        thumbnails.forEach(img => img.classList.remove('active'));

        // Add the 'active' class to the hovered thumbnail
        this.classList.add('active');
    });
});

function toggleNavbar() {
    const navbarContent = document.getElementById('navbarContent');
    navbarContent.classList.remove('show'); // Hide the menu
}

</script>
</body>

</html>
EOL

# Create parse-csv.js
echo "Creating parse-csv.js script..."
cat > parse-csv.js << 'EOL'
const axios = require('axios');
const csv = require('csv-parser');
const fs = require('fs');
const path = require('path');
const ejs = require('ejs');

// Load configuration from config.json
const config = require('./config.json');

// Define directories
const baseDir = config.project.directory;
const outputDir = path.join(baseDir, 'public/products');
const imagesDir = path.join(baseDir, 'public/images');
const dataDir = path.join(baseDir, 'data');

// Base URL configurations
const BASE_URL = config.project.baseUrl;
const PRODUCTS_BASE_URL = `${BASE_URL}/public/products`;
const IMAGES_BASE_URL = `${BASE_URL}/public/images`;

// Create directories if they don't exist
[outputDir, imagesDir].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
});

// Function to download image
async function downloadImage(url, filepath) {
    try {
        const response = await axios({
            url,
            responseType: 'stream'
        });
        return new Promise((resolve, reject) => {
            const writer = fs.createWriteStream(filepath);
            response.data.pipe(writer);
            writer.on('finish', resolve);
            writer.on('error', reject);
        });
    } catch (error) {
        console.error(`Error downloading image from ${url}:`, error.message);
        throw error;
    }
}

// Function to sanitize filename
function sanitizeFilename(filename) {
    return filename.toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/(^-|-$)/g, '');
}

// Function to generate products XML
async function generateProductsXML(products) {
    try {
        const xmlContent = `<?xml version="1.0" encoding="UTF-8"?>
<products>
    ${products.map(product => `
    <product>
        <title><![CDATA[${product.Title}]]></title>
        <price><![CDATA[${product['Regular Price']}]]></price>
        <product_link><![CDATA[${PRODUCTS_BASE_URL}/${sanitizeFilename(product.Title)}.html]]></product_link>
        <category><![CDATA[${product.Category}]]></category>
        <image_url><![CDATA[${IMAGES_BASE_URL}/${sanitizeFilename(product.Title)}${path.extname(product.Image) || '.jpg'}]]></image_url>
    </product>`).join('')}
</products>`;

        fs.writeFileSync(path.join(dataDir, 'products_database.xml'), xmlContent);
        console.log('Products XML generated successfully!');
    } catch (error) {
        console.error('Error generating XML:', error);
    }
}

// Function to generate sitemap
async function generateSitemap(products) {
    const sitemapContent = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url>
        <loc>${BASE_URL}</loc>
        <lastmod>${new Date().toISOString()}</lastmod>
        <priority>1.0</priority>
    </url>
    ${products.map(product => `
    <url>
        <loc>${PRODUCTS_BASE_URL}/${sanitizeFilename(product.Title)}.html</loc>
        <lastmod>${new Date().toISOString()}</lastmod>
        <priority>0.8</priority>
    </url>
    `).join('')}
</urlset>`;

    fs.writeFileSync(path.join(baseDir, 'sitemap.xml'), sitemapContent);
    console.log('Sitemap generated successfully!');
}

// Process CSV and generate HTML
let allProducts = [];

fs.createReadStream(path.join(dataDir, 'products.csv'))
    .pipe(csv())
    .on('data', async (row) => {
        try {
            // Store product data
            allProducts.push(row);

            // Generate image filename from title
            const imageExt = path.extname(row.Image) || '.jpg';
            const imageName = `${sanitizeFilename(row.Title)}${imageExt}`;
            const imagePath = path.join(imagesDir, imageName);
            const relativeImagePath = `/public/images/${imageName}`;

            // Download image
            await downloadImage(row.Image, imagePath);
            console.log(`Downloaded image: ${imagePath}`);

            // Prepare data for template
            const templateData = {
                title: row.Title,
                image: relativeImagePath,
                price: row['Regular Price'],
                category: row.Category,
                shortDescription: row.Short_description,
                description: row.description
            };

            // Generate HTML using EJS template
            const templatePath = path.join(baseDir, 'views', 'product.ejs');
            const template = fs.readFileSync(templatePath, 'utf8');
            const htmlContent = ejs.render(template, templateData);

            // Save HTML file
            const htmlFilename = `${sanitizeFilename(row.Title)}.html`;
            const htmlPath = path.join(outputDir, htmlFilename);
            fs.writeFileSync(htmlPath, htmlContent);

            console.log(`Generated: ${htmlFilename}`);
        } catch (error) {
            console.error(`Error processing row for ${row.Title}:`, error.message);
        }
    })
    .on('end', async () => {
        try {
            // Generate sitemap
            await generateSitemap(allProducts);

            // Generate products XML
            await generateProductsXML(allProducts);

            console.log('Processing complete!');
        } catch (error) {
            console.error('Error in final processing:', error);
        }
    })
    .on('error', (error) => {
        console.error('Error reading CSV:', error);
    });
EOL

# Move files to correct locations after directories are created
move_project_files

# Set web server permissions
echo "Setting web server permissions..."
sudo chown -R www-data:www-data "$PROJECT_DIR"

echo "Setup completed successfully!"
echo "Now run: cd $PROJECT_DIR && node parse-csv.js"
