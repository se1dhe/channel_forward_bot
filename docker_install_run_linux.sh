#!/bin/bash

echo "============================================="
echo "Docker Bot Installation and Launch Script for Linux"
echo "============================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."

    # Install prerequisites
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

    # Add Docker repository
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    # Install Docker
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    # Add current user to docker group to run docker without sudo
    sudo usermod -aG docker $USER

    echo "Docker has been installed."
    echo "You need to log out and log back in for docker group membership to take effect."
    echo "After logging back in, please run this script again."
    exit 0
else
    echo "Docker is already installed."
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "Docker daemon is not running. Starting Docker..."
    sudo systemctl start docker

    if ! docker info &> /dev/null; then
        echo "Failed to start Docker daemon. Please check Docker installation."
        exit 1
    fi
fi

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Git not found. Installing Git..."
    sudo apt-get update
    sudo apt-get install -y git
    echo "Git has been installed."
else
    echo "Git is already installed."
fi

# Create a temporary directory for the bot
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Ask for repository token
echo "Please provide the GitHub repository token:"
read -p "Enter token: " REPO_TOKEN

# Clone the repository
echo "Cloning repository..."
git clone https://github.com/se1dhe/channel_forward_bot.git .
# Configure git to use the token for authentication
git config --local "url.https://${REPO_TOKEN}@github.com/.insteadOf" "https://github.com/"
git pull

# Create Dockerfile
echo "Creating Dockerfile..."
cat > Dockerfile << 'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY . /app/
RUN pip install --no-cache-dir -r requirements.txt
CMD ["python", "forwarder.py"]
EOF

# Create installation directory
INSTALL_DIR="$HOME/channel_forward_bot"
mkdir -p "$INSTALL_DIR"

# Create restart script
echo "Creating auto-restart script..."
cat > "$INSTALL_DIR/restart_bot.sh" << 'EOF'
#!/bin/bash

echo "Checking if channel_forward_bot container is running..."
if ! docker ps -q -f name=channel_forward_bot > /dev/null 2>&1; then
    echo "Container is not running. Attempting to restart..."
    if ! docker start channel_forward_bot > /dev/null 2>&1; then
        echo "Container doesn't exist. Creating new container..."
        docker run -d --name channel_forward_bot --restart unless-stopped -v "$HOME/channel_forward_bot_data:/app/data" channel_forward_bot
    else
        echo "Container restarted successfully."
    fi
else
    echo "Container is already running."
fi
EOF

# Make restart script executable
chmod +x "$INSTALL_DIR/restart_bot.sh"

# Create crontab setup script
echo "Creating crontab setup script..."
cat > "$INSTALL_DIR/setup_cron_restart.sh" << EOF
#!/bin/bash

# Remove any existing cron jobs for the bot
crontab -l | grep -v "restart_bot.sh" | crontab -

# Add new cron jobs for restart
(crontab -l 2>/dev/null; echo "@reboot $INSTALL_DIR/restart_bot.sh > /dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "0 * * * * $INSTALL_DIR/restart_bot.sh > /dev/null 2>&1") | crontab -

echo "Cron jobs set up. Bot will restart on system reboot and every hour."
EOF

# Make crontab setup script executable
chmod +x "$INSTALL_DIR/setup_cron_restart.sh"

# Build the Docker image
echo "Building Docker image..."
docker build -t channel_forward_bot .

# Create a directory for persistent data
DATA_DIR="$HOME/channel_forward_bot_data"
mkdir -p "$DATA_DIR"

# Menu for bot operations
while true; do
    clear
    echo "============================================="
    echo "Channel Forward Bot - Docker Management Console"
    echo "============================================="
    echo "1. Run the bot (with latest code)"
    echo "2. Update and run the bot"
    echo "3. Stop the bot"
    echo "4. View logs"
    echo "5. Setup auto-restart (on system startup and hourly)"
    echo "6. Exit"
    echo ""

    read -p "Enter your choice: " choice

    case $choice in
        1)
            echo "Starting the bot in Docker container..."
            docker stop channel_forward_bot 2>/dev/null
            docker rm channel_forward_bot 2>/dev/null
            docker run -d --name channel_forward_bot --restart unless-stopped -v "$DATA_DIR:/app/data" channel_forward_bot
            echo "Bot is running in background. Use option 4 to view logs."
            read -p "Press Enter to continue..."
            ;;
        2)
            echo "Stopping existing container if running..."
            docker stop channel_forward_bot 2>/dev/null
            docker rm channel_forward_bot 2>/dev/null

            echo "Please provide the GitHub repository token again:"
            read -p "Enter token: " REPO_TOKEN

            echo "Updating repository..."
            cd "$TEMP_DIR"
            git config --local "url.https://${REPO_TOKEN}@github.com/.insteadOf" "https://github.com/"
            git pull

            echo "Rebuilding Docker image..."
            docker build -t channel_forward_bot .

            echo "Starting updated bot..."
            docker run -d --name channel_forward_bot --restart unless-stopped -v "$DATA_DIR:/app/data" channel_forward_bot
            echo "Bot updated and running in background. Use option 4 to view logs."
            read -p "Press Enter to continue..."
            ;;
        3)
            echo "Stopping the bot..."
            docker stop channel_forward_bot
            docker rm channel_forward_bot
            echo "Bot stopped."
            read -p "Press Enter to continue..."
            ;;
        4)
            echo "Displaying logs (press Ctrl+C to exit)..."
            docker logs -f channel_forward_bot
            ;;
        5)
            echo "Setting up auto-restart for the bot..."
            "$INSTALL_DIR/setup_cron_restart.sh"
            read -p "Press Enter to continue..."
            ;;
        6)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press Enter to continue..."
            ;;
    esac
done