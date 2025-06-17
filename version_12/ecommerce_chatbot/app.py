from flask import Flask, request, jsonify
from flask_cors import CORS
import woocommerce_bot  # Import your Python module with the method

app = Flask(__name__)
CORS(app, origins=["*"])  # Allow all origins for testing
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
    app.run(debug=True, host='0.0.0.0', port=5000)
