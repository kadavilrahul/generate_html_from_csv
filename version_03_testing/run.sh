#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Setting up and running the Version 03 project..."

# 1. Environment Setup: Create and activate a Python virtual environment for the backend.
echo "1. Setting up Python virtual environment for backend..."
python3 -m venv version03_venv_backend
source version03_venv_backend/bin/activate
echo "Python virtual environment activated."

# 2. Dependency Installation: Install all required packages.

# Install backend Python dependencies
echo "2.1. Installing backend Python dependencies..."
pip install -r backend/requirements.txt
echo "Backend Python dependencies installed."

# Install frontend Node.js dependencies
echo "2.2. Installing frontend Node.js dependencies..."
(cd frontend && npm install)
echo "Frontend Node.js dependencies installed."

# Install root Gulp Node.js dependencies
echo "2.3. Installing root Gulp Node.js dependencies..."
npm install
echo "Root Gulp Node.js dependencies installed."

# 3. Execution: Run the project's main scripts.

echo "3. Running the project components:"

# Run Backend in a new terminal
echo "Starting backend (Python Flask)..."
(cd backend && python run.py) &
BACKEND_PID=$!
echo "Backend started with PID: $BACKEND_PID"

# Run Frontend development server in a new terminal
echo "Starting frontend (React development server)..."
(cd frontend && npm start) &
FRONTEND_PID=$!
echo "Frontend started with PID: $FRONTEND_PID"

echo "Project setup and execution complete."
echo "Backend is running in the background. Frontend is running in the background."
echo "You can access the frontend at http://localhost:3000 (if webpack-dev-server opens it automatically)."
echo "To stop the processes, use 'kill $BACKEND_PID $FRONTEND_PID' or 'pkill -f \"python run.py|webpack serve\"'."

# Optional: Run Gulp CSV to HTML conversion
echo "To run Gulp CSV to HTML conversion, execute 'npm run gulp csvToHtml' in a new terminal."
echo "This will generate HTML files in version_03/dist."

# 4. Cleanup (Optional): Add a commented-out section for deactivating the virtual environment or cleaning up if necessary.
: '
# To deactivate the Python virtual environment:
# deactivate

# To stop the running processes (if they are still active):
# kill $BACKEND_PID $FRONTEND_PID
'
