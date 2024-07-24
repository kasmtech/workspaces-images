#!/bin/bash

# Exit on error
set -e

# Function to install an extension
install_extension() {
    code --no-sandbox --user-data-dir="." --install-extension "$1"
}

# List of extensions to install
extensions=(
    "ms-toolsai.jupyter"
    "ms-python.python"
    # "ms-vscode.cpptools"
    "esbenp.prettier-vscode"
    "dbaeumer.vscode-eslint"
    # Add more extensions here
)

# Check if code command is available
if ! command -v code &> /dev/null
then
    echo "Error: Visual Studio Code is not installed or not in PATH"
    exit 1
fi

# Install extensions
for extension in "${extensions[@]}"
do
    echo "Installing extension: $extension"
    install_extension "$extension"
done

echo "All extensions have been installed successfully!"