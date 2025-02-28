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
    /* CSS styles remain the same */
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
    
    /* Rest of the CSS remains unchanged */
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

    /* Added source badge to distinguish results */
    .source-badge {
    position: absolute;
    top: 5px;
    right: 5px;
    padding: 3px 8px;
    font-size: 10px;
    border-radius: 3px;
    color: white;
    }
    .postgres-source {
    background-color: #336791;
    }
    .wordpress-source {
    background-color: #21759b;
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
<div class="debug-info" style="background: #f8f8f8; padding: 10px; margin-bottom: 20px; font-family: monospace; display: none;">
    <h3>Debug Information</h3>
    <div id="debug-content"></div>
</div>

<?php
// PostgreSQL Database configuration
$pg_config = array(
    'host'    => 'localhost',
    'port'    => '5432',
    'dbname'   => 'products_db',  // Update with your Postgres DB name
    'user'    => 'products_user', // Update with your Postgres DB user
    'password' => 'products_2@' // Update with your Postgres DB password
);

// WordPress MySQL Database configuration (new)
$wp_config = array(
    'host'     => 'localhost',    // Update with your WordPress DB host
    'dbname'   => 'products_db',    // Update with your WordPress DB name
    'user'     => 'products_user',      // Update with your WordPress DB user
    'password' => 'products_2@',  // Update with your WordPress DB password
    'prefix'   => 'wp_'           // WordPress table prefix (usually wp_)
);

// Debug function to log info
function debug_log($message, $data = null) {
    echo "<script>
        var debugDiv = document.querySelector('.debug-info');
        debugDiv.style.display = 'block';
        var content = document.getElementById('debug-content');
        content.innerHTML += '<p>" . esc_js($message) . "';
        if (" . json_encode($data !== null) . ") {
            content.innerHTML += ': ' + JSON.stringify(" . json_encode($data) . ");
        }
        content.innerHTML += '</p>';
    </script>";
}

// Helper function for JavaScript escaping
function esc_js($str) {
    return str_replace(
        array("\\", "'", "\"", "\r", "\n"),
        array("\\\\", "\\'", "\\\"", "\\r", "\\n"),
        $str
    );
}

// Get and sanitize the search term
$search_term = isset($_GET['term']) ? sanitize_text_field($_GET['term']) : '';
$combined_results = array();
$total_results = 0;
$errors = array();

// Function to standardize product structure from different sources
function normalize_product($product, $source) {
    $product['source'] = $source;
    return $product;
}

try {
    // Only proceed if we have a search term
    if (!empty($search_term)) {
        // POSTGRESQL SEARCH
        try {
            // Create database connection string
            $conn_string = sprintf(
                "host=%s port=%s dbname=%s user=%s password=%s",
                $pg_config['host'],
                $pg_config['port'],
                $pg_config['dbname'],
                $pg_config['user'],
                $pg_config['password']
            );

            // Create database connection
            $pg_conn = pg_connect($conn_string);

            if (!$pg_conn) {
                throw new Exception("PostgreSQL Connection failed: " . pg_last_error());
            }

            // Prepare query with ILIKE for case-insensitive search
            $pg_query = "SELECT title, price, product_link, category, image_url 
                        FROM products 
                        WHERE title ILIKE $1 
                        LIMIT 20"; // Reduced limit to leave room for WordPress results

            // Add wildcards to search term
            $search_pattern = "%{$search_term}%";
            
            // Execute the query
            $pg_result = pg_query_params($pg_conn, $pg_query, array($search_pattern));

            if (!$pg_result) {
                throw new Exception("PostgreSQL query execution failed: " . pg_last_error());
            }

            // Process PostgreSQL results
            while ($product = pg_fetch_assoc($pg_result)) {
                $combined_results[] = normalize_product($product, 'postgres');
                $total_results++;
            }

            // Clean up PostgreSQL resources
            pg_free_result($pg_result);
            pg_close($pg_conn);
        } catch (Exception $e) {
            $errors[] = "PostgreSQL Error: " . $e->getMessage();
        }

        // WORDPRESS MYSQL SEARCH - More robust implementation
        try {
            // Create MySQL connection with improved error handling
            $wp_conn = mysqli_init();
            if (!$wp_conn) {
                throw new Exception("mysqli_init failed");
            }
            
            // Set connection timeout
            mysqli_options($wp_conn, MYSQLI_OPT_CONNECT_TIMEOUT, 5);
            
            // Connect with error reporting
            if (!mysqli_real_connect(
                $wp_conn,
                $wp_config['host'],
                $wp_config['user'],
                $wp_config['password'],
                $wp_config['dbname']
            )) {
                throw new Exception("WordPress MySQL Connection failed: " . mysqli_connect_error() . " (Error #" . mysqli_connect_errno() . ")");
            }

            // Set character set
            mysqli_set_charset($wp_conn, 'utf8mb4');

            // Prepare search pattern for MySQL
            $search_pattern = '%' . mysqli_real_escape_string($wp_conn, $search_term) . '%';
            
            // First check if the WooCommerce tables exist
            $table_exists = false;
            $result = mysqli_query($wp_conn, "SHOW TABLES LIKE '{$wp_config['prefix']}posts'");
            if (mysqli_num_rows($result) > 0) {
                $table_exists = true;
            }
            
            if (!$table_exists) {
                throw new Exception("WordPress tables not found with prefix '{$wp_config['prefix']}'");
            }

            // Simplified query for WordPress posts that works on more MySQL configurations
            $wp_query = "
                SELECT 
                    p.ID, 
                    p.post_title as title, 
                    p.guid as product_link,
                    '' as category,
                    '' as price,
                    '' as image_url
                FROM 
                    {$wp_config['prefix']}posts p
                WHERE 
                    p.post_type IN ('post', 'page', 'product') 
                    AND p.post_status = 'publish'
                    AND p.post_title LIKE ?
                LIMIT 20";
            
            // Prepare and execute the query
            $stmt = mysqli_prepare($wp_conn, $wp_query);
            if (!$stmt) {
                throw new Exception("Prepare statement failed: " . mysqli_error($wp_conn));
            }
            
            mysqli_stmt_bind_param($stmt, 's', $search_pattern);
            
            if (!mysqli_stmt_execute($stmt)) {
                throw new Exception("Execute statement failed: " . mysqli_stmt_error($stmt));
            }
            
            $wp_result = mysqli_stmt_get_result($stmt);
            if (!$wp_result) {
                throw new Exception("Get result failed: " . mysqli_stmt_error($stmt));
            }
            
            // Process WordPress results
            while ($post = mysqli_fetch_assoc($wp_result)) {
                // Now fetch additional metadata for each post
                $post_id = $post['ID'];
                
                // Get category
                $cat_query = "
                    SELECT 
                        t.name
                    FROM 
                        {$wp_config['prefix']}terms t
                        JOIN {$wp_config['prefix']}term_taxonomy tt ON t.term_id = tt.term_id
                        JOIN {$wp_config['prefix']}term_relationships tr ON tt.term_taxonomy_id = tr.term_taxonomy_id
                    WHERE 
                        tr.object_id = ?
                        AND tt.taxonomy IN ('category', 'product_cat')
                    LIMIT 1";
                
                $cat_stmt = mysqli_prepare($wp_conn, $cat_query);
                if ($cat_stmt) {
                    mysqli_stmt_bind_param($cat_stmt, 'i', $post_id);
                    mysqli_stmt_execute($cat_stmt);
                    $cat_result = mysqli_stmt_get_result($cat_stmt);
                    if ($cat_row = mysqli_fetch_assoc($cat_result)) {
                        $post['category'] = $cat_row['name'];
                    }
                    mysqli_stmt_close($cat_stmt);
                }
                
                // Get price if it's a WooCommerce product
                $price_query = "
                    SELECT 
                        meta_value as price
                    FROM 
                        {$wp_config['prefix']}postmeta
                    WHERE 
                        post_id = ?
                        AND meta_key = '_price'
                    LIMIT 1";
                
                $price_stmt = mysqli_prepare($wp_conn, $price_query);
                if ($price_stmt) {
                    mysqli_stmt_bind_param($price_stmt, 'i', $post_id);
                    mysqli_stmt_execute($price_stmt);
                    $price_result = mysqli_stmt_get_result($price_stmt);
                    if ($price_row = mysqli_fetch_assoc($price_result)) {
                        $post['price'] = $price_row['price'];
                    }
                    mysqli_stmt_close($price_stmt);
                }
                
                // Get featured image URL
                $image_query = "
                    SELECT 
                        p2.guid as image_url
                    FROM 
                        {$wp_config['prefix']}postmeta pm
                        JOIN {$wp_config['prefix']}posts p2 ON pm.meta_value = p2.ID
                    WHERE 
                        pm.post_id = ?
                        AND pm.meta_key = '_thumbnail_id'
                    LIMIT 1";
                
                $image_stmt = mysqli_prepare($wp_conn, $image_query);
                if ($image_stmt) {
                    mysqli_stmt_bind_param($image_stmt, 'i', $post_id);
                    mysqli_stmt_execute($image_stmt);
                    $image_result = mysqli_stmt_get_result($image_stmt);
                    if ($image_row = mysqli_fetch_assoc($image_result)) {
                        $post['image_url'] = $image_row['image_url'];
                    }
                    mysqli_stmt_close($image_stmt);
                }
                
                // Format WordPress result and add to combined results
                $combined_results[] = normalize_product($post, 'wordpress');
                $total_results++;
            }

            // Clean up WordPress MySQL resources
            mysqli_stmt_close($stmt);
            mysqli_close($wp_conn);
        } catch (Exception $e) {
            $errors[] = "WordPress MySQL Error: " . $e->getMessage();
        }

        // Display results if we have any
        if ($total_results > 0) {
            ?>
            <div class="search-results-container">
                <h3>Search Results for: "<?php echo esc_html($search_term); ?>"</h3>
                <div class="product-grid">
                <?php
                foreach ($combined_results as $product) {
                ?>
                <div class="product-item" style="position: relative;">
                    <?php if ($product['source'] == 'postgres'): ?>
                        <span class="source-badge postgres-source">PG</span>
                    <?php else: ?>
                        <span class="source-badge wordpress-source">WP</span>
                    <?php endif; ?>
                    
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
                    <?php if (isset($product['price']) && !empty($product['price'])): ?>
                    <div class="price">
                    Rs. <?php echo esc_html($product['price']); ?>
                    </div>
                    <?php endif; ?>
                    <?php if (isset($product['category']) && !empty($product['category'])): ?>
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
    }
} catch (Exception $e) {
    ?>
    <div class="error-message">
        <p>An error occurred while searching for products:</p>
        <p><?php echo esc_html($e->getMessage()); ?></p>
        <?php if (!empty($errors)): ?>
            <ul>
                <?php foreach($errors as $error): ?>
                    <li><?php echo esc_html($error); ?></li>
                <?php endforeach; ?>
            </ul>
        <?php endif; ?>
    </div>
    <?php
}
?>
</body>
</html>
