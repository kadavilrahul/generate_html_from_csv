from flask import Flask, request, jsonify
from flask_cors import CORS
import woocommerce_bot  # Import your Python module with the method
import socket
import sys

app = Flask(__name__)
CORS(app, origins=["*"])  # Allow all origins for testing

def find_free_port(start_port=5000, max_port=5010):
    """Find a free port starting from start_port"""
    for port in range(start_port, max_port + 1):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('', port))
                return port
        except OSError:
            continue
    return None

# Expose the multiply method via HTTP
@app.route('/message', methods=['GET'])
def multiply():
    try:
        msg = str(request.args.get('input'))
        result = woocommerce_bot.process_query(msg, None)
        return jsonify({'result': result})
    except (TypeError, ValueError):
        return jsonify({'error': 'Invalid input, please provide a valid input.'}), 400

# Run the Flask app
if __name__ == '__main__':
    # Find an available port
    port = find_free_port(5000, 5010)
    if port is None:
        print("ERROR: No available ports found between 5000-5010")
        sys.exit(1)
    
    # Save the port to a file for the script to read
    with open('flask_port.txt', 'w') as f:
        f.write(str(port))
    
    print(f"Starting Flask app on port {port}")
    app.run(debug=True, host='0.0.0.0', port=port)
