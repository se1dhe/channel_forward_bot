@echo off
setlocal enabledelayedexpansion

echo ====================================================================
echo       Channel Forward Bot - Windows Deployment Script
echo ====================================================================
echo This script will:
echo 1. Check and install Docker and Git if needed
echo 2. Clone or update the bot repository
echo 3. Set up Python and install dependencies
echo 4. Build and run the bot in a Docker container
echo ====================================================================
echo.

:: Set colors for output
set "CYAN=[36m"
set "GREEN=[32m"
set "YELLOW=[33m"
set "RED=[31m"
set "NC=[0m"

:: Function to check internet connection
:check_internet
echo %CYAN%Checking internet connection...%NC%
ping -n 1 -w 1000 google.com >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%Error: No internet connection. Please check your connection and try again.%NC%
    goto end_with_pause
)
echo %GREEN%Internet connection available.%NC%
echo.

:: Check if Docker is installed
:check_docker
echo %CYAN%Checking if Docker is installed...%NC%
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%Docker is not installed. Installing Docker Desktop...%NC%
    echo %YELLOW%Please download and install Docker Desktop from https://www.docker.com/products/docker-desktop%NC%
    echo %YELLOW%After installation, press any key to continue...%NC%
    pause > nul

    :: Check again after installation
    docker --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo %RED%Docker installation failed. Please install Docker Desktop manually.%NC%
        goto end_with_pause
    )
) else (
    echo %GREEN%Docker is already installed.%NC%
)
echo.

:: Check if Docker is running
:check_docker_running
echo %CYAN%Checking if Docker is running...%NC%
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%Docker is installed but not running. Please start Docker Desktop manually.%NC%
    echo %YELLOW%After starting Docker Desktop, press any key to continue...%NC%
    pause > nul

    :: Check again after manual start
    docker info >nul 2>&1
    if %errorlevel% neq 0 (
        echo %RED%Docker is still not running. Please ensure Docker Desktop is running correctly.%NC%
        goto end_with_pause
    )
)
echo %GREEN%Docker is running properly.%NC%
echo.

:: Check if Git is installed
:check_git
echo %CYAN%Checking if Git is installed...%NC%
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%Git is not installed. Installing Git...%NC%
    echo %YELLOW%Please download and install Git from https://git-scm.com/download/win%NC%
    echo %YELLOW%After installation, press any key to continue...%NC%
    pause > nul

    :: Check again after installation
    git --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo %RED%Git installation failed. Please install Git manually.%NC%
        goto end_with_pause
    )
) else (
    echo %GREEN%Git is already installed.%NC%
)
echo.

:: Get bot directory
:get_bot_directory
set "default_dir=C:\channel_forward_bot"
echo %YELLOW%Enter the directory for the bot (or press Enter to use %default_dir%):
set /p "bot_dir="
if "%bot_dir%"=="" set "bot_dir=%default_dir%"
echo %GREEN%Using directory: %bot_dir%%NC%
echo.

:: Clone or update the repository
:clone_or_update_repo
echo %CYAN%Checking bot repository...%NC%
set "repo_url=https://github.com/se1dhe/channel_forward_bot.git"
set "github_token="

if exist "%bot_dir%\.git" (
    :: Repository exists, update it
    echo %CYAN%Repository found. Updating to the latest version...%NC%
    cd /d "%bot_dir%"

    git pull
    if %errorlevel% neq 0 (
        :: Possibly a private repository
        echo %YELLOW%Error updating repository. It might be a private repository.%NC%
        echo %YELLOW%Enter GitHub Personal Access Token (or leave empty to abort):
        set /p github_token=

        if not "!github_token!"=="" (
            set "token_repo_url=https://!github_token!@github.com/se1dhe/channel_forward_bot.git"
            git remote set-url origin !token_repo_url!
            git pull
            if %errorlevel% neq 0 (
                echo %RED%Error updating repository. Check your token and repository access.%NC%
                goto end_with_pause
            )

            :: Restore original URL to avoid storing the token
            git remote set-url origin %repo_url%
        ) else (
            echo %RED%No token provided. Cannot update repository.%NC%
            goto end_with_pause
        )
    )

    echo %GREEN%Repository successfully updated.%NC%
) else (
    :: Repository doesn't exist, clone it
    echo %CYAN%Repository not found. Cloning...%NC%

    if not exist "%bot_dir%" mkdir "%bot_dir%"

    git clone %repo_url% "%bot_dir%"
    if %errorlevel% neq 0 (
        :: Possibly a private repository
        echo %YELLOW%Error cloning repository. It might be a private repository.%NC%
        echo %YELLOW%Enter GitHub Personal Access Token (or leave empty to abort):
        set /p github_token=

        if not "!github_token!"=="" (
            set "token_repo_url=https://!github_token!@github.com/se1dhe/channel_forward_bot.git"
            git clone !token_repo_url! "%bot_dir%"
            if %errorlevel% neq 0 (
                echo %RED%Error cloning repository. Check your token and repository access.%NC%
                goto end_with_pause
            )
        ) else (
            echo %RED%No token provided. Cannot clone repository.%NC%
            goto end_with_pause
        )
    )

    echo %GREEN%Repository successfully cloned.%NC%
)
echo.

:: Move to bot directory
cd /d "%bot_dir%"

:: Check and download Python if needed
:check_python
echo %CYAN%Checking Python installation...%NC%
python --version 2>nul | findstr /C:"Python 3.12" >nul
if %errorlevel% neq 0 (
    echo %YELLOW%Python 3.12 not found. Installing Python...%NC%
    echo %YELLOW%Please download and install Python 3.12 from https://www.python.org/downloads/%NC%
    echo %YELLOW%Make sure to check 'Add Python to PATH' during installation.%NC%
    echo %YELLOW%After installation, press any key to continue...%NC%
    pause > nul

    :: Check again after installation
    python --version 2>nul | findstr /C:"Python 3.12" >nul
    if %errorlevel% neq 0 (
        echo %RED%Python 3.12 installation could not be verified.%NC%
        echo %YELLOW%Trying to continue anyway. If there are errors, please install Python 3.12 manually.%NC%
    )
) else (
    echo %GREEN%Python 3.12 is already installed.%NC%
)
echo.

:: Install Python dependencies
:install_dependencies
echo %CYAN%Upgrading pip...%NC%
python -m pip install --upgrade pip
if %errorlevel% neq 0 (
    echo %RED%Error upgrading pip. Trying to continue...%NC%
)

echo %CYAN%Installing Python dependencies...%NC%
python -m pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo %RED%Error installing Python dependencies. Please install them manually.%NC%
    goto end_with_pause
)
echo %GREEN%Python dependencies installed successfully.%NC%
echo.

:: Create Dockerfile if it doesn't exist
:create_dockerfile
echo %CYAN%Checking for Dockerfile...%NC%
if not exist "Dockerfile" (
    echo %CYAN%Dockerfile not found. Creating...%NC%
    (
        echo FROM python:3.12-slim
        echo.
        echo WORKDIR /app
        echo.
        echo COPY requirements.txt .
        echo RUN pip install --no-cache-dir -r requirements.txt
        echo.
        echo COPY . .
        echo.
        echo CMD ["python", "forwarder.py"]
    ) > Dockerfile
    echo %GREEN%Dockerfile created.%NC%
) else (
    echo %GREEN%Dockerfile already exists.%NC%
)
echo.

:: Create data directory
:create_data_dir
set "data_dir=%USERPROFILE%\channel_forward_bot_data"
echo %CYAN%Setting up data directory: %data_dir%%NC%
if not exist "%data_dir%" mkdir "%data_dir%"
if not exist "%data_dir%\logs" mkdir "%data_dir%\logs"

:: Copy config file if needed
if not exist "%data_dir%\config.ini" (
    if exist "config.ini" (
        echo %CYAN%Copying configuration file to data directory...%NC%
        copy "config.ini" "%data_dir%\config.ini"
        echo %GREEN%Configuration file copied to %data_dir%\config.ini%NC%
    )
)
echo.

:: Build Docker image
:build_docker_image
echo %CYAN%Building Docker image...%NC%
docker build -t channel_forward_bot .
if %errorlevel% neq 0 (
    echo %RED%Error building Docker image.%NC%
    goto end_with_pause
)
echo %GREEN%Docker image built successfully.%NC%
echo.

:: Check for running container
:check_container
echo %CYAN%Checking for running container...%NC%
docker ps -q --filter "name=channel_forward_bot" > temp.txt
set /p running_container=<temp.txt
del temp.txt

if not "%running_container%"=="" (
    echo %YELLOW%Found running container. Stopping it...%NC%
    docker stop channel_forward_bot
    docker rm channel_forward_bot
)

:: Run Docker container
:run_container
echo %CYAN%Starting Docker container...%NC%
docker run -d ^
    --name channel_forward_bot ^
    --restart unless-stopped ^
    -v "%data_dir%:/app/data" ^
    -v "%data_dir%\config.ini:/app/config.ini" ^
    -v "%data_dir%\logs:/app/logs" ^
    channel_forward_bot

if %errorlevel% neq 0 (
    echo %RED%Error starting Docker container.%NC%
    goto end_with_pause
)
echo %GREEN%Docker container started successfully.%NC%
echo.

:: Success message
echo %GREEN%========== INSTALLATION COMPLETED SUCCESSFULLY ==========%NC%
echo %GREEN%Channel Forward Bot has been installed and started in a Docker container.%NC%
echo %GREEN%Bot data is stored in: %data_dir%%NC%
echo %GREEN%To view bot logs use: docker logs channel_forward_bot%NC%
echo %GREEN%To stop the bot use: docker stop channel_forward_bot%NC%
echo %GREEN%To start the bot again use: docker start channel_forward_bot%NC%
echo %GREEN%=================================================%NC%
echo.

:: Offer to view logs
echo %YELLOW%Do you want to view the bot logs? (y/n)%NC%
set /p view_logs=
if /i "%view_logs%"=="y" (
    docker logs -f channel_forward_bot
)

:end_with_pause
echo.
echo %YELLOW%Press any key to exit...%NC%
pause > nul
exit