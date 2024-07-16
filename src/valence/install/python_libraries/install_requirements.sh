#!/usr/bin/env bash
set -e

# Script name
SCRIPT_NAME=$(basename "$0")

# Function to display usage information
usage() {
    echo "Usage: $SCRIPT_NAME [OPTIONS]"
    echo "Install Python packages from all .txt files in the requirements directory."
    echo
    echo "Options:"
    echo "  -d, --dir DIRECTORY  Specify the requirements directory (default: ./requirements)"
    echo "  -h, --help           Display this help message and exit"
}

# Default requirements directory
REQUIREMENTS_DIR="./requirements"

# Parse command-line options
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            REQUIREMENTS_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Full path to the requirements directory
REQUIREMENTS_PATH="$SCRIPT_DIR/$REQUIREMENTS_DIR"

# Check if the requirements directory exists
if [ ! -d "$REQUIREMENTS_PATH" ]; then
    echo "Error: Requirements directory '$REQUIREMENTS_DIR' not found in the script directory."
    exit 1
fi

# Install packages from all .txt files in the requirements directory
echo "Installing packages from all .txt files in $REQUIREMENTS_DIR..."
for req_file in "$REQUIREMENTS_PATH"/*.txt; do
    if [ -f "$req_file" ]; then
        echo "Installing packages from $(basename "$req_file")..."
        pip install --no-cache-dir -r "$req_file"
    fi
done

echo "Installation complete."