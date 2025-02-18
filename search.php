<a href="<?php echo esc_url($product['product_link']); ?>" target="_blank">
    <img src="<?php echo esc_url($product['image_url']); ?>" 
         alt="<?php echo esc_attr($product['title']); ?>">
</a><h4>
    <a href="<?php echo esc_url($product['product_link']); ?>" target="_blank">
        <?php echo esc_html($product['title']); ?>
    </a>
</h4><?php
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
    'host'     => 'loaclhost',
    'username' => 'products_user',
    'password' => 'products_2@',
    'database' => 'products_db'
);

// Get and sanitize the search term
$search_term = isset($_GET['term']) ? sanitize_text_field($_GET['term']) : '';

try {
    // Create database connection
    $mysqli = new mysqli(
        $db_config['host'],
        $db_config['username'],
        $db_config['password'],
        $db_config['database']
    );

    // Check connection
    if ($mysqli->connect_error) {
        throw new Exception("Database Connection failed: " . $mysqli->connect_error);
    }

    // Set charset
    if (!$mysqli->set_charset("utf8")) {
        throw new Exception("Error loading character set utf8: " . $mysqli->error);
    }

    if (!empty($search_term)) {
        // Prepare query
        $query = "SELECT title, price, product_link, category, image_url 
                 FROM products 
                 WHERE title LIKE ? 
                 LIMIT 12";

        $stmt = $mysqli->prepare($query);
        if (!$stmt) {
            throw new Exception("Query preparation failed: " . $mysqli->error);
        }

        // Add wildcards to search term
        $search_pattern = "%{$search_term}%";
        $stmt->bind_param("s", $search_pattern);

        // Execute the query
        if (!$stmt->execute()) {
            throw new Exception("Query execution failed: " . $stmt->error);
        }

        $result = $stmt->get_result();

        if ($result->num_rows > 0) {
            ?>
            <div class="search-results-container">
                <h3>Search Results for: "<?php echo esc_html($search_term); ?>"</h3>
                <div class="product-grid">
                    <?php
                    while ($product = $result->fetch_assoc()) {
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
                                <h4><a href="<?php echo esc_url($product['product_link']); ?>" target="_blank"><?php echo esc_html($product['title']); ?></a></h4>

                                <?php if (isset($product['price'])): ?>
                                    <div class="price">
                                        Rs. <?php echo esc_html($product['price']); ?>
                                    </div>
                                <?php endif; ?>

                                <?php if (isset($product['short_description'])): ?>
                                    <div class="description">
                                        <?php echo esc_html(substr($product['short_description'], 0, 100)) . '...'; ?>
                                    </div>
                                <?php endif; ?>

                                <?php if (isset($product['product_link'])): ?>
                                    <a href="<?php echo esc_url($product['product_link']); ?>" 
                                       class="view-details" 
                                       target="_blank">
                                        View Details
                                    </a>
                                <?php endif; ?>

                                <?php if (isset($product['category'])): ?>
                                    <div class="category">
                                        Category: <?php echo esc_html($product['category']); ?>
                                    </div>
                                <?php endif; ?>
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
        $stmt->close();
    }

    $mysqli->close();

} catch (Exception $e) {
    ?>
    <div class="error-message">
        <p>An error occurred while searching for products:</p>
        <p><?php echo esc_html($e->getMessage()); ?></p>
    </div>
    <?php
}
?>

<style>
    body {
        font-family: Arial, sans-serif;
        margin: 0;
        padding: 20px;
        background-color: #f5f5f5;
    }
    .search-results-container {
        max-width: 1200px;
        margin: 0 auto;
        padding: 20px;
    }
    .product-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
        gap: 25px;
        margin: 30px 0;
    }
    .product-item {
        border: 1px solid #ddd;
        padding: 15px;
        border-radius: 8px;
        background: white;
        transition: transform 0.3s ease, box-shadow 0.3s ease;
    }
    .product-item:hover {
        transform: translateY(-5px);
        box-shadow: 0 5px 15px rgba(0,0,0,0.1);
    }
    .product-image {
        margin-bottom: 15px;
        aspect-ratio: 1;
        overflow: hidden;
        border-radius: 4px;
    }
    .product-image img {
        width: 100%;
        height: 100%;
        object-fit: cover;
    }
    .no-image {
        background: #f5f5f5;
        height: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        color: #666;
    }
    .product-details {
        text-align: center;
    }
    .price {
        font-weight: bold;
        color: #4CAF50;
        margin: 8px 0;
        font-size: 1.2em;
    }
    .description {
        font-size: 0.9em;
        color: #666;
        margin: 10px 0;
        line-height: 1.4;
    }
    .view-details {
        display: inline-block;
        padding: 8px 15px;
        background: #f8f9fa;
        color: #333;
        text-decoration: none;
        border-radius: 4px;
        margin-top: 10px;
    }
    .category {
        font-size: 0.9em;
        color: #666;
        margin-top: 8px;
        background: #f0f0f0;
        padding: 4px 8px;
        border-radius: 4px;
        display: inline-block;
    }
    .error-message {
        color: #721c24;
        background-color: #f8d7da;
        border: 1px solid #f5c6cb;
        padding: 15px;
        border-radius: 6px;
        margin: 20px 0;
    }
    .no-results {
        text-align: center;
        padding: 30px;
        background: #f8f9fa;
        border-radius: 6px;
        color: #666;
    }
</style>