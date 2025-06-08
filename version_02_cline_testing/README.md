# Version 03: Codebase Rebuild and CSV to HTML Conversion

This project is a rebuild of an existing codebase, incorporating a new feature to generate HTML pages from CSV files using Gulp.

## Project Structure

```
version_03/
├── backend/          # Backend code (Python/Flask)
│   ├── app/          # Application logic
│   │   ├── __init__.py
│   │   ├── models.py   # Data models
│   │   ├── views.py    # API endpoints
│   │   ├── utils.py    # Utility functions
│   ├── config.py     # Configuration settings
│   ├── requirements.txt # Python dependencies
│   └── run.py        # Application entry point
├── frontend/         # Frontend code (React)
│   ├── src/          # Source files
│   │   ├── components/ # Reusable UI components
│   │   ├── App.js      # Main application component
│   │   ├── App.css
│   │   ├── index.js    # Entry point
│   │   ├── index.css   # Global CSS
│   ├── public/       # Static assets (HTML, CSS, images)
│   │   ├── index.html  # Main HTML file
│   ├── package.json  # Node.js dependencies for frontend
│   ├── webpack.config.js # Webpack configuration
├── data/             # Input CSV files for Gulp
│   ├── input.csv     # Sample CSV file
├── templates/        # HTML templates for Gulp
│   ├── template.html # Sample HTML template
├── gulpfile.js       # Gulp tasks for CSV to HTML conversion and frontend build
├── package.json      # Node.js dependencies for Gulp
├── README.md         # Project documentation
├── run.sh            # Script to set up and run the project
```

## Setup and Running the Project

### Prerequisites

*   Python 3.x
*   Node.js and npm (or yarn)
*   Gulp CLI (`npm install -g gulp-cli`)

### Installation

1.  **Backend Dependencies:**
    ```bash
    cd backend
    pip install -r requirements.txt
    cd ..
    ```
2.  **Frontend Dependencies:**
    ```bash
    cd frontend
    npm install
    cd ..
    ```
3.  **Gulp Dependencies:**
    ```bash
    npm install
    ```

### Running the Project

You can use the `run.sh` script to set up and run the project.

```bash
./run.sh
```

Alternatively, you can run components individually:

*   **Run Backend:**
    ```bash
    cd backend
    python run.py
    ```
*   **Run Frontend (Development Server):**
    ```bash
    cd frontend
    npm start
    ```
    (This will typically open the application in your browser at `http://localhost:3000`)
*   **Run Gulp CSV to HTML Conversion:**
    ```bash
    gulp csvToHtml
    ```
    This will read `data/input.csv` and `templates/template.html` and generate HTML files in the `dist` directory.

## Gulp Tasks

*   `gulp csvToHtml`: Converts CSV data from `data/input.csv` into HTML files using `templates/template.html` and outputs them to `dist/`.
*   `gulp build`: Placeholder for frontend build process (e.g., Webpack production build).
*   `gulp watch`: Placeholder for watching file changes and triggering tasks.
*   `gulp default`: Runs `csvToHtml`, `build`, and `watch` tasks.

## API Endpoints

*   **CSV to HTML Conversion:**
    *   `POST /api/convert`
    *   Request Body:
        ```json
        {
          "csv_file": "...", // Base64 encoded CSV file
          "template": "..."  // HTML template string
        }
        ```
    *   Response:
        ```json
        {
          "status": "success",
          "html": "..."      // Generated HTML
        }
