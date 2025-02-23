<?php
// Enable error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Helper functions
function sanitize_text_field($str) {
    return htmlspecialchars(strip_tags(trim($str)));
}

function esc_attr($str) {
    return htmlspecialchars($str, ENT_QUOTES, 'UTF-8');
}

function esc_url($url) {
    return filter_var($url, FILTER_SANITIZE_URL);
}

function esc_html($str) {
    return htmlspecialchars($str, ENT_QUOTES, 'UTF-8');
}
?>
<!DOCTYPE html>
<html>
<head>
    <style>
        /* Added new CSS for tile layout */
        .search-results-container {
            padding: 20px;
            max-width: 1200px;
            margin: 0 auto;
        }

        .product-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
            gap: 20px;
            padding: 20px 0;
        }

        .product-item {
            border: 1px solid #eee;
            border-radius: 8px;
            overflow: hidden;
            transition: transform 0.2s;
            background: white;
            display: flex;
            flex-direction: column;
        }

        .product-item:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }

        .product-image {
            width: 100%;
            height: 200px;
            overflow: hidden;
        }

        .product-image img {
            width: 100%;
            height: 100%;
            object-fit: cover;
            transition: transform 0.3s;
        }

        .product-image img:hover {
            transform: scale(1.05);
        }

        .no-image {
            width: 100%;
            height: 100%;
            background: #f5f5f5;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #666;
        }

        .product-details {
            padding: 10px;
            text-align: center;
        }

        .product-details h4 {
            margin: 5px 0;
            font-size: 14px;
            line-height: 1.3;
            height: 36px;
            overflow: hidden;
        }

        .product-details h4 a {
            color: #333;
            text-decoration: none;
        }

        .price {
            font-weight: bold;
            color: #e44d26;
            margin: 5px 0;
        }

        .category {
            font-size: 12px;
            color: #666;
            margin: 5px 0;
        }

        .view-details {
            display: inline-block;
            padding: 5px 15px;
            background: #4CAF50;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            margin-top: 5px;
            font-size: 12px;
        }

        .view-details:hover {
            background: #45a049;
        }

        .no-results, .error-message {
            text-align: center;
            padding: 20px;
            background: #f8f8f8;
            border-radius: 8px;
            margin: 20px auto;
            max-width: 600px;
        }

        .error-message {
            background: #fee;
            color: #c00;
        }

        @media (max-width: 768px) {
            .product-grid {
                grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
                gap: 15px;
            }

            .product-image {
                height: 150px;
            }
        }
    </style>
</head>
<body>
<?php
// Database configuration
$db_config = array(
    'host'    => 'localhost',
    'port'    => '5432',
    'dbname'   => 'products_db',
    'user'    => 'products_user',
    'password' => 'products_2@'
);

// Get and sanitize the search term
$search_term = isset($_GET['term']) ? sanitize_text_field($_GET['term']) : '';

try {
    // Create database connection string
    $conn_string = sprintf(
        "host=%s port=%s dbname=%s user=%s password=%s",
        $db_config['host'],
        $db_config['port'],
        $db_config['dbname'],
        $db_config['user'],
        $db_config['password']
    );

    // Create database connection
    $dbconn = pg_connect($conn_string);

    if (!$dbconn) {
        throw new Exception("Database Connection failed: " . pg_last_error());
    }

    if (!empty($search_term)) {
        // Prepare query with ILIKE for case-insensitive search
        $query = "SELECT title, price, product_link, category, image_url 
                 FROM products 
                 WHERE title ILIKE $1 
                 LIMIT 12";

        // Add wildcards to search term
        $search_pattern = "%{$search_term}%";
        
        // Execute the query
        $result = pg_query_params($dbconn, $query, array($search_pattern));

        if (!$result) {
            throw new Exception("Query execution failed: " . pg_last_error());
        }

        if (pg_num_rows($result) > 0) {
            ?>
            <div class="search-results-container">
                <h3>Search Results for: "<?php echo esc_html($search_term); ?>"</h3>
                <div class="product-grid">
                    <?php
                    while ($product = pg_fetch_assoc($result)) {
                        ?>
                        <div class="product-item">
                            <div class="product-image">
                                <?php if (!empty($product['image_url'])): ?>
                                    <a href="<?php echo esc_url($product['product_link']); ?>" target="_blank">
                                        <img src="<?php echo esc_url($product['image_url']); ?>" 
                                             alt="<?php echo esc_attr($product['title']); ?>">
                                    </a>
                                <?php else: ?>
                                    <div class="no-image">No Image Available</div>
                                <?php endif; ?>
                            </div>
                            <div class="product-details">
                                <h4>
                                    <a href="<?php echo esc_url($product['product_link']); ?>" target="_blank">
                                        <?php echo esc_html($product['title']); ?>
                                    </a>
                                </h4>
                                <?php if (isset($product['price'])): ?>
                                    <div class="price">
                                        Rs. <?php echo esc_html($product['price']); ?>
                                    </div>
                                <?php endif; ?>
                                <?php if (isset($product['category'])): ?>
                                    <div class="category">
                                        <?php echo esc_html($product['category']); ?>
                                    </div>
                                <?php endif; ?>
                                <a href="<?php echo esc_url($product['product_link']); ?>" 
                                   class="view-details" 
                                   target="_blank">
                                    View Details
                                </a>
                            </div>
                        </div>
                        <?php
                    }
                    ?>
                </div>
            </div>
            <?php
        } else {
            ?>
            <div class="no-results">
                <p>No products found matching your search for "<?php echo esc_html($search_term); ?>".</p>
            </div>
            <?php
        }

        // Clean up
        pg_free_result($result);
    }

    // Close connection
    pg_close($dbconn);

} catch (Exception $e) {
    ?>
    <div class="error-message">
        <p>An error occurred while searching for products:</p>
        <p><?php echo esc_html($e->getMessage()); ?></p>
    </div>
    <?php
}
?>
</body>
</html>
