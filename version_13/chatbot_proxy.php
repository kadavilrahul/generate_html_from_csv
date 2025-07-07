<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Get the input parameter
$input = isset($_GET['input']) ? $_GET['input'] : '';

if (empty($input)) {
    echo json_encode(['error' => 'No input provided']);
    exit;
}

// Auto-detect API endpoint
function getApiUrl() {
    // Method 1: Check for config file
    $config_file = __DIR__ . '/chatbot_config.txt';
    if (file_exists($config_file)) {
        $api_url = trim(file_get_contents($config_file));
        if (!empty($api_url)) {
            return $api_url;
        }
    }
    
    // Method 2: Auto-detect server IP
    $server_ip = $_SERVER['SERVER_ADDR'] ?? $_SERVER['LOCAL_ADDR'] ?? '127.0.0.1';
    
    // Method 3: Try to get external IP if server IP is local
    if (in_array($server_ip, ['127.0.0.1', '::1', 'localhost'])) {
        // Try to get external IP
        $external_ip = @file_get_contents('http://ipecho.net/plain');
        if ($external_ip && filter_var($external_ip, FILTER_VALIDATE_IP)) {
            $server_ip = trim($external_ip);
        }
    }
    
    return "http://{$server_ip}:5000";
}

$api_base_url = getApiUrl();
$api_url = $api_base_url . '/message?input=' . urlencode($input);

// Make the API call
$context = stream_context_create([
    'http' => [
        'timeout' => 10,
        'method' => 'GET'
    ]
]);

$response = @file_get_contents($api_url, false, $context);

if ($response === false) {
    echo json_encode(['error' => 'Failed to connect to chatbot API']);
} else {
    // Return the response as-is
    echo $response;
}
?>