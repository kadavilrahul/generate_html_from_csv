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

// Database configuration
$db_config = array(
    'host'     => 'localhost',
    'port'     => '5432',
    'dbname'   => 'products_db',
    'user'     => 'products_user',
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
                                        Category: <?php echo esc_html($product['category']); ?>
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