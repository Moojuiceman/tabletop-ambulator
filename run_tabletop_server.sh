#!/bin/bash

# --------------------------------------------------------------------------
# Script: run_tabletop_server.sh
#
# Description:
# This script automates the setup and launch process for the Tabletop Ambulator project.
# It performs the following tasks:
# - Checks if required directories exist under $HOME/source/repos and creates them if missing.
# - Clones the project repository from GitHub if it's not already present.
# - Installs Git, Node.js, npm, Yarn, and Docker if they are not installed on the system.
# - Starts a PostgreSQL Docker container named 'tabletop_server' with specified credentials 
#   if it doesn't exist, and starts the container if it exists but isn’t running.
# - Exports DATABASE_URL if it’s not already set in the environment.
# - Installs project dependencies using Yarn (with `sudo` permissions for npm).
# - Updates outdated packages like `caniuse-lite` and `browserslist`.
# - Builds the project if it hasn’t been built yet.
# - Starts the backend server as a detached process and logs output to `server.log`.
# - Launches the React development server for frontend interaction.
#
# Pre-requisite:
# 1. Install WSL2, open Powershell or Terminal in admin mode:
#    wsl.exe --install -d Ubuntu
# 2. Restart your computer.
# 3. Open Terminal or Powershell and run Ubuntu
# 4. Update and (optional) Install micro:
#    sudo apt update && sudo apt upgrade -y && sudo apt install micro -y
#
# Usage:
# 1. Save this script as `run_tabletop_server.sh` in your home directory.
# 2. Make it executable:
#    chmod +x $HOME/run_tabletop_server.sh
# 3. Run the script:
#    bash run_tabletop_server.sh
#
# Note:
# Replace the REPO_URL variable with the actual GitHub repository URL if different.
# --------------------------------------------------------------------------

# Define variables
PROJECT_PATH="$HOME/source/repos/tabletop-ambulator"
REPO_URL="https://github.com/64bits/tabletop-ambulator.git"  # Replace with the actual GitHub URL if different
POSTGRES_PASSWORD="password"  # Set PostgreSQL password here

# Create the source and repos directories if they don't exist
if [ ! -d "$HOME/source/repos" ]; then
    echo "Creating directories: $HOME/source/repos"
    mkdir -p "$HOME/source/repos"
fi

# Check if Git is installed
if ! command -v git &> /dev/null; then
    echo "Git not found. Installing Git..."
    sudo apt update
    sudo apt install -y git
fi

# Check if the project directory exists; if not, clone the repository
if [ ! -d "$PROJECT_PATH" ]; then
    echo "Project directory $PROJECT_PATH not found. Cloning repository..."
    git clone "$REPO_URL" "$PROJECT_PATH" || { echo "Failed to clone repository."; exit 1; }
fi

# Change to the project directory
cd "$PROJECT_PATH" || { echo "Directory $PROJECT_PATH not found after cloning"; exit 1; }

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Node.js not found. Installing Node.js..."
    sudo apt update
    sudo apt install -y nodejs npm
fi

# Check if Yarn is installed
if ! command -v yarn &> /dev/null; then
    echo "Yarn not found. Installing Yarn..."
    sudo npm install --global yarn
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    sudo apt install -y docker.io
fi

# Check if the Docker container 'tabletop_server' exists, and create it if not
if [ -z "$(sudo docker ps -a -q -f name=tabletop_server)" ]; then
    echo "Docker container 'tabletop_server' not found. Creating and starting the container..."
    sudo docker run --name tabletop_server -p 127.0.0.1:5432:5432 -e POSTGRES_USER=tabletop -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD -e POSTGRES_DB=tabletop_server -d postgres
else
    # Start the container if it exists but is not running
    if [ -z "$(sudo docker ps -q -f name=tabletop_server)" ]; then
        echo "Starting existing Docker container 'tabletop_server'..."
        sudo docker start tabletop_server
    fi
fi

# Export DATABASE_URL if it's not already set
DATABASE_IP=$(sudo docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' tabletop_server)
export DATABASE_URL="postgres://tabletop:$POSTGRES_PASSWORD@$DATABASE_IP:5432/tabletop_server"
echo "DATABASE_URL set to $DATABASE_URL"

# Check if node_modules folder exists to confirm dependencies are installed
if [ ! -d "node_modules" ]; then
    echo "Dependencies not found. Installing dependencies..."
    sudo yarn install
fi

# Update outdated packages (browserslist and caniuse-lite)
echo "Updating caniuse-lite and browserslist..."
npx browserslist@latest --update-db

yarn upgrade caniuse-lite browserslist

# Check if build folder exists
if [ ! -d "build" ]; then
    echo "Build folder not found. Building the project..."
    yarn build
fi

# Run db tasks
npx sequelize-cli db:migrate

# Set legacy OpenSSL provider if necessary
export NODE_OPTIONS=--openssl-legacy-provider

# Start the server in the background and log output
echo "Starting the backend server as a detached process..."
nohup node server/server.js > server.log 2>&1 &

# Start the frontend development server
echo "Starting the React development server..."
yarn start
