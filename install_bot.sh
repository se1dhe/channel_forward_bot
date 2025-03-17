#!/bin/bash

# =================================================================
# Channel Forward Bot - Linux/macOS Deployment Script
# =================================================================
# This script will:
# 1. Check and install Docker and Git if needed
# 2. Clone or update the bot repository
# 3. Set up Python and install dependencies
# 4. Build and run the bot in a Docker container
# =================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local message=$1
    local color=$2
    echo -e "${color}${message}${NC}"
}

# Function to check command success
check_command_success() {
    local exit_code=$1
    local error_message=$2

    if [ $exit_code -ne 0 ]; then
        print_message "$error_message" "$RED"
        exit $exit_code
    fi
}

# Function to get bot directory
get_bot_directory() {
    local default_path="$HOME/channel_forward_bot"

    print_message "Enter the directory for the bot (or press Enter to use $default_path):" "$YELLOW"
    read user_path

    if [ -z "$user_path" ]; then
        echo "$default_path"
    else
        echo "$user_path"
    fi
}

# Function to check internet connection
check_internet_connection() {
    if ping -c 1 google.com > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        # For Linux, detect distribution
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            echo "$ID"
        else
            echo "unknown"
        fi
    fi
}

# Check and install package manager
ensure_package_manager() {
    local os_type=$1

    case $os_type in
        ubuntu|debian)
            if ! command -v apt-get > /dev/null 2>&1; then
                print_message "Package manager apt-get not found. Check your system." "$RED"
                exit 1
            fi
            sudo apt-get update
            ;;
        centos|fedora|rhel)
            if ! command -v yum > /dev/null 2>&1; then
                print_message "Package manager yum not found. Check your system." "$RED"
                exit 1
            fi
            ;;
        macos)
            if ! command -v brew > /dev/null 2>&1; then
                print_message "Homebrew not installed. Installing Homebrew..." "$YELLOW"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                check_command_success $? "Error installing Homebrew."
            fi
            ;;
        *)
            print_message "Unsupported operating system. Please install Docker and Git manually." "$RED"
            exit 1
            ;;
    esac
}

# Install Docker for different OS
install_docker() {
    local os_type=$1

    case $os_type in
        ubuntu|debian)
            print_message "Installing necessary packages..." "$CYAN"
            sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

            print_message "Adding Docker GPG key..." "$CYAN"
            curl -fsSL https://download.docker.com/linux/$os_type/gpg | sudo apt-key add -

            print_message "Adding Docker repository..." "$CYAN"
            sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$os_type $(lsb_release -cs) stable"

            print_message "Updating package list..." "$CYAN"
            sudo apt-get update

            print_message "Installing Docker..." "$CYAN"
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io
            ;;
        centos|fedora|rhel)
            print_message "Installing necessary packages..." "$CYAN"
            sudo yum install -y yum-utils

            print_message "Adding Docker repository..." "$CYAN"
            sudo yum-config-manager --add-repo https://download.docker.com/linux/$os_type/docker-ce.repo

            print_message "Installing Docker..." "$CYAN"
            sudo yum install -y docker-ce docker-ce-cli containerd.io
            ;;
        macos)
            print_message "Installing Docker for macOS..." "$CYAN"
            brew install --cask docker
            print_message "Docker Desktop installed. Please start the Docker application manually." "$YELLOW"
            print_message "After starting Docker, press Enter to continue..." "$YELLOW"
            read -r
            ;;
        *)
            print_message "Unsupported operating system. Please install Docker manually." "$RED"
            exit 1
            ;;
    esac
}

# Add user to docker group
add_user_to_docker_group() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_message "Adding user $USER to docker group..." "$CYAN"
        sudo usermod -aG docker $USER
        print_message "User added to docker group." "$GREEN"
        print_message "You may need to log out and back in for this to take effect." "$YELLOW"
        print_message "Do you want to continue without logging out? (y/n)" "$YELLOW"
        read continue_without_logout

        if [[ $continue_without_logout != "y" && $continue_without_logout != "Y" ]]; then
            print_message "Please log out, log back in, and run the script again." "$YELLOW"
            exit 0
        fi

        # Temporary solution to run Docker without sudo for current session
        print_message "Trying to run Docker without sudo for current session..." "$CYAN"
        if sudo docker info > /dev/null 2>&1; then
            print_message "Docker is running with root privileges. Continuing..." "$GREEN"
        else
            print_message "Failed to run Docker. Please log out, log back in, and run the script again." "$RED"
            exit 1
        fi
    fi
}

# Install Git for different OS
install_git() {
    local os_type=$1

    case $os_type in
        ubuntu|debian)
            print_message "Installing Git..." "$CYAN"
            sudo apt-get install -y git
            ;;
        centos|fedora|rhel)
            print_message "Installing Git..." "$CYAN"
            sudo yum install -y git
            ;;
        macos)
            print_message "Installing Git..." "$CYAN"
            brew install git
            ;;
        *)
            print_message "Unsupported operating system. Please install Git manually." "$RED"
            exit 1
            ;;
    esac
}

# Main script starts here

# Check internet connection
print_message "Checking internet connection..." "$CYAN"
if ! check_internet_connection; then
    print_message "Error: No internet connection. Please check your connection and try again." "$RED"
    exit 1
fi
print_message "Internet connection available." "$GREEN"

# Detect operating system
os_type=$(detect_os)
print_message "Detected operating system: $os_type" "$CYAN"

# Check and install package manager
ensure_package_manager "$os_type"

# Check and install Docker
print_message "Checking Docker installation..." "$CYAN"
if ! command -v docker > /dev/null 2>&1; then
    print_message "Docker not installed. Installing Docker..." "$YELLOW"
    install_docker "$os_type"

    # Start Docker service
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_message "Starting Docker service..." "$CYAN"
        sudo systemctl start docker
        sudo systemctl enable docker
    fi

    print_message "Docker successfully installed." "$GREEN"

    # Add user to docker group
    add_user_to_docker_group
else
    print_message "Docker already installed." "$GREEN"

    # Check Docker service status
    if [[ "$OSTYPE" != "darwin"* ]]; then
        if ! sudo systemctl is-active --quiet docker; then
            print_message "Docker service is not running. Starting service..." "$YELLOW"
            sudo systemctl start docker
            check_command_success $? "Error starting Docker service."
        fi
    fi

    # Check if Docker is working
    if ! docker info > /dev/null 2>&1; then
        if [[ "$OSTYPE" != "darwin"* ]]; then
            # For Linux - check if user is in docker group
            if ! groups | grep -q docker; then
                print_message "Current user is not in the docker group. Adding user to the group..." "$YELLOW"
                add_user_to_docker_group
            else
                print_message "Docker is installed but not working. Check Docker service status." "$RED"
                exit 1
            fi
        else
            # For macOS - need to start Docker Desktop
            print_message "Docker is installed but not running. Please start Docker Desktop manually." "$YELLOW"
            print_message "After starting Docker, press Enter to continue..." "$YELLOW"
            read -r
        fi
    fi
fi

# Check if Docker is working
print_message "Checking Docker functionality..." "$CYAN"
if ! docker info > /dev/null 2>&1; then
    print_message "Docker is installed but not working. You may need administrator privileges." "$YELLOW"

    if sudo docker info > /dev/null 2>&1; then
        print_message "Docker is working but requires sudo. Will use sudo for Docker commands." "$YELLOW"
        docker_prefix="sudo"
    else
        print_message "Docker is not working even with administrator privileges. Check Docker installation." "$RED"
        exit 1
    fi
else
    print_message "Docker is working correctly." "$GREEN"
    docker_prefix=""
fi

# Check and install Git
print_message "Checking Git installation..." "$CYAN"
if ! command -v git > /dev/null 2>&1; then
    print_message "Git not installed. Installing Git..." "$YELLOW"
    install_git "$os_type"
    check_command_success $? "Error installing Git."
    print_message "Git successfully installed." "$GREEN"
else
    print_message "Git already installed." "$GREEN"
fi

# Get bot directory
bot_directory=$(get_bot_directory)

# Clone or update repository
print_message "Checking bot repository..." "$CYAN"

repo_url="https://github.com/se1dhe/channel_forward_bot.git"
github_token=""

if [ -d "$bot_directory" ] && [ -d "$bot_directory/.git" ]; then
    # Repository exists, update it
    print_message "Repository found. Updating to latest version..." "$CYAN"
    cd "$bot_directory" || exit 1

    git pull
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        # Might be a private repository
        print_message "Error updating repository. It might be a private repository." "$YELLOW"
        print_message "Enter GitHub Personal Access Token (or leave empty to abort):" "$YELLOW"
        read -r github_token

        if [ -n "$github_token" ]; then
            token_repo_url="https://$github_token@github.com/se1dhe/channel_forward_bot.git"
            git remote set-url origin "$token_repo_url"
            git pull
            check_command_success $? "Error updating repository. Check your token and repository access."

            # Restore original URL to avoid storing token in config
            git remote set-url origin "$repo_url"
        else
            print_message "No token provided. Cannot update repository." "$RED"
            exit 1
        fi
    fi

    print_message "Repository successfully updated." "$GREEN"
else
    # Repository doesn't exist, clone it
    print_message "Repository not found. Cloning..." "$CYAN"

    mkdir -p "$bot_directory"
    git clone "$repo_url" "$bot_directory"
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        # Might be a private repository
        print_message "Error cloning repository. It might be a private repository." "$YELLOW"
        print_message "Enter GitHub Personal Access Token (or leave empty to abort):" "$YELLOW"
        read -r github_token

        if [ -n "$github_token" ]; then
            token_repo_url="https://$github_token@github.com/se1dhe/channel_forward_bot.git"
            git clone "$token_repo_url" "$bot_directory"
            check_command_success $? "Error cloning repository. Check your token and repository access."
        else
            print_message "No token provided. Cannot clone repository." "$RED"
            exit 1
        fi
    fi

    print_message "Repository successfully cloned." "$GREEN"
fi

# Change to bot directory
cd "$bot_directory" || exit 1

# Check Python version
print_message "Checking Python installation..." "$CYAN"
if command -v python3.12 > /dev/null 2>&1; then
    python_cmd="python3.12"
    print_message "Python 3.12 is installed." "$GREEN"
elif command -v python3 > /dev/null 2>&1; then
    python_version=$(python3 --version 2>&1)
    if [[ $python_version == *"3.12"* ]]; then
        python_cmd="python3"
        print_message "Python 3.12 is installed: $python_version" "$GREEN"
    else
        print_message "Python 3.12 not found. Found $python_version instead." "$YELLOW"
        print_message "Please install Python 3.12 manually to ensure compatibility." "$YELLOW"
        print_message "Press Enter to continue with current Python version, or Ctrl+C to abort..." "$YELLOW"
        read -r
        python_cmd="python3"
    fi
else
    print_message "Python 3 is not installed. Please install Python 3.12 manually." "$RED"
    print_message "Press Enter to try continuing with system Python, or Ctrl+C to abort..." "$YELLOW"
    read -r
    python_cmd="python"
fi

# Upgrade pip
print_message "Upgrading pip to latest version..." "$CYAN"
$python_cmd -m pip install --upgrade pip
check_command_success $? "Error upgrading pip"
print_message "pip successfully upgraded." "$GREEN"

# Install Python dependencies
print_message "Installing Python dependencies..." "$CYAN"
$python_cmd -m pip install -r requirements.txt
check_command_success $? "Error installing Python dependencies"
print_message "Python dependencies successfully installed." "$GREEN"

# Create Dockerfile if it doesn't exist
dockerfile_path="$bot_directory/Dockerfile"

if [ ! -f "$dockerfile_path" ]; then
    print_message "Dockerfile not found. Creating Dockerfile..." "$CYAN"

    cat > "$dockerfile_path" << EOF
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "forwarder.py"]
EOF

    print_message "Dockerfile created." "$GREEN"
fi

# Create data directory
data_dir="$HOME/channel_forward_bot_data"

if [ ! -d "$data_dir" ]; then
    print_message "Creating data directory: $data_dir" "$CYAN"
    mkdir -p "$data_dir"
fi

# Create logs directory
if [ ! -d "$data_dir/logs" ]; then
    mkdir -p "$data_dir/logs"
fi

# Check and copy config file to data directory
config_source_path="$bot_directory/config.ini"
config_dest_path="$data_dir/config.ini"

if [ ! -f "$config_dest_path" ] && [ -f "$config_source_path" ]; then
    print_message "Copying configuration file to data directory..." "$CYAN"
    cp "$config_source_path" "$config_dest_path"
    print_message "Configuration file copied to $config_dest_path" "$GREEN"
fi

# Build Docker image
print_message "Building Docker image..." "$CYAN"
$docker_prefix docker build -t channel_forward_bot .
check_command_success $? "Error building Docker image"
print_message "Docker image successfully built." "$GREEN"

# Check for running container
print_message "Checking for running container..." "$CYAN"
running_container=$($docker_prefix docker ps -q --filter "name=channel_forward_bot")

if [ -n "$running_container" ]; then
    print_message "Found running container. Stopping it..." "$YELLOW"
    $docker_prefix docker stop channel_forward_bot
    $docker_prefix docker rm channel_forward_bot
fi

# Run Docker container
print_message "Starting Docker container..." "$CYAN"
$docker_prefix docker run -d \
    --name channel_forward_bot \
    --restart unless-stopped \
    -v "$data_dir:/app/data" \
    -v "$data_dir/config.ini:/app/config.ini" \
    -v "$data_dir/logs:/app/logs" \
    channel_forward_bot

check_command_success $? "Error starting Docker container"
print_message "Docker container successfully started." "$GREEN"

# Success message
print_message "========== INSTALLATION COMPLETED SUCCESSFULLY ==========" "$GREEN"
print_message "Channel Forward Bot has been installed and started in a Docker container." "$GREEN"
print_message "Bot data is stored in: $data_dir" "$GREEN"
print_message "To view bot logs use: $docker_prefix docker logs channel_forward_bot" "$GREEN"
print_message "To stop the bot use: $docker_prefix docker stop channel_forward_bot" "$GREEN"
print_message "To restart the bot use: $docker_prefix docker start channel_forward_bot" "$GREEN"
print_message "=================================================" "$GREEN"

# Offer to view logs
print_message "Do you want to view the bot logs? (y/n)" "$YELLOW"
read view_logs

if [ "$view_logs" == "y" ] || [ "$view_logs" == "Y" ]; then
    $docker_prefix docker logs -f channel_forward_bot
fi

print_message "Press Enter to exit..." "$YELLOW"
read -r