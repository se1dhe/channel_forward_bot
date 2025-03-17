@echo off
echo =============================================
echo Docker Bot Installation and Launch Script for Windows
echo =============================================

:: Check if Docker is installed
docker --version > nul 2>&1
if %errorlevel% neq 0 (
    echo Docker not found. Installing Docker Desktop...

    :: Check system architecture
    echo Checking system requirements...
    wmic os get osarchitecture | find "64-bit" > nul
    if %errorlevel% neq 0 (
        echo Error: Docker Desktop requires a 64-bit Windows. Exiting.
        pause
        exit /b 1
    )

    :: Download Docker Desktop Installer
    echo Downloading Docker Desktop...
    curl -L -o DockerDesktopInstaller.exe https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe

    :: Install Docker Desktop
    echo Installing Docker Desktop...
    DockerDesktopInstaller.exe install --quiet

    :: Delete installer after installation
    del DockerDesktopInstaller.exe

    echo Docker has been installed. You may need to restart your computer.
    echo After restart, please run this script again.
    pause
    exit /b 0
) else (
    echo Docker is already installed.
)

:: Check if Docker is running
docker info > nul 2>&1
if %errorlevel% neq 0 (
    echo Docker is not running. Please start Docker Desktop and run this script again.
    pause
    exit /b 1
)

:: Check if git is installed
git --version > nul 2>&1
if %errorlevel% neq 0 (
    echo Git not found. Installing Git...
    curl -L -o git-installer.exe https://github.com/git-for-windows/git/releases/download/v2.39.0.windows.1/Git-2.39.0-64-bit.exe
    git-installer.exe /VERYSILENT /NORESTART
    del git-installer.exe
    echo Git has been installed.
    :: Add Git to PATH for the current session
    set "PATH=%PATH%;C:\Program Files\Git\cmd"
) else (
    echo Git is already installed.
)

:: Create a temporary directory for the bot
set TEMP_DIR=%TEMP%\channel_forward_bot_tmp
if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"
cd "%TEMP_DIR%"

:: Ask for repository token
echo Please provide the GitHub repository token:
set /p REPO_TOKEN=Enter token:

:: Clone the repository
echo Cloning repository...
git clone https://github.com/se1dhe/channel_forward_bot.git .
:: Configure git to use the token for authentication
git config --local "url.https://%REPO_TOKEN%@github.com/.insteadOf" "https://github.com/"
git pull

:: Create Dockerfile
echo Creating Dockerfile...
(
echo FROM python:3.12-slim
echo WORKDIR /app
echo COPY . /app/
echo RUN pip install --no-cache-dir -r requirements.txt
echo CMD ["python", "forwarder.py"]
) > Dockerfile

:: Build and run the Docker container
echo Building Docker image...
docker build -t channel_forward_bot .

:: Create a directory for persistent data
set DATA_DIR=%USERPROFILE%\channel_forward_bot_data
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%"

:: Menu for bot operations
:menu
cls
echo =============================================
echo Channel Forward Bot - Docker Management Console
echo =============================================
echo 1. Run the bot (with latest code)
echo 2. Update and run the bot
echo 3. Stop the bot
echo 4. View logs
echo 5. Exit
echo.

set /p choice=Enter your choice:

if "%choice%"=="1" (
    echo Starting the bot in Docker container...
    docker stop channel_forward_bot 2>nul
    docker rm channel_forward_bot 2>nul
    docker run -d --name channel_forward_bot -v "%DATA_DIR%:/app/data" channel_forward_bot
    echo Bot is running in background. Use option 4 to view logs.
    pause
    goto menu
)
if "%choice%"=="2" (
    echo Stopping existing container if running...
    docker stop channel_forward_bot 2>nul
    docker rm channel_forward_bot 2>nul

    echo Please provide the GitHub repository token again:
    set /p REPO_TOKEN=Enter token:

    echo Updating repository...
    cd "%TEMP_DIR%"
    git config --local "url.https://%REPO_TOKEN%@github.com/.insteadOf" "https://github.com/"
    git pull

    echo Rebuilding Docker image...
    docker build -t channel_forward_bot .

    echo Starting updated bot...
    docker run -d --name channel_forward_bot -v "%DATA_DIR%:/app/data" channel_forward_bot
    echo Bot updated and running in background. Use option 4 to view logs.
    pause
    goto menu
)
if "%choice%"=="3" (
    echo Stopping the bot...
    docker stop channel_forward_bot
    docker rm channel_forward_bot
    echo Bot stopped.
    pause
    goto menu
)
if "%choice%"=="4" (
    echo Displaying logs (press Ctrl+C to exit)...
    docker logs -f channel_forward_bot
    goto menu
)
if "%choice%"=="5" (
    echo Exiting...
    exit /b 0
)

echo Invalid choice. Please try again.
pause
goto menu