@echo off
setlocal enabledelayedexpansion

:: Set title for the window
title Telegram Forwarder Bot

:: Set colors
color 0A

:: Create a function to pause with message
:pause_with_message
echo.
echo Press any key to continue...
pause > nul
goto :eof

:: Print banner
echo ========================================================
echo              TELEGRAM FORWARDER BOT LAUNCHER
echo ========================================================
echo.

:: Go to script directory
cd /d "%~dp0"
echo Current directory: %CD%
echo.

:: Set variables
set LOG_DIR=logs
if not exist "%LOG_DIR%" (
    echo Creating logs directory...
    mkdir "%LOG_DIR%" 2>&1
    if ERRORLEVEL 1 (
        echo ERROR: Failed to create logs directory!
        call :pause_with_message
    ) else (
        echo Logs directory created successfully.
    )
)

:: Check for Python installation
echo Checking Python installation...
where python >nul 2>&1
if ERRORLEVEL 1 (
    echo ERROR: Python is not installed or not in PATH!
    echo Please install Python 3.6 or higher.
    call :pause_with_message
    exit /b 1
)

:: Show Python version
python --version
if ERRORLEVEL 1 (
    echo ERROR: Failed to get Python version!
    call :pause_with_message
)

:: Check if forwarder.py exists
echo.
echo Checking for bot script (forwarder.py)...
if not exist "forwarder.py" (
    echo ERROR: forwarder.py not found in the current directory!
    echo Make sure you're running this script from the correct folder.
    call :pause_with_message
    exit /b 1
) else (
    echo Bot script found.
)

:: Check if config.ini exists
echo.
echo Checking configuration file...
if not exist "config.ini" (
    echo WARNING: config.ini not found!
    echo The bot will not work without a proper configuration.
    echo Please create config.ini file before starting the bot.
    call :pause_with_message
) else (
    echo Configuration file found.
)

:: Prepare virtual environment
echo.
echo Checking virtual environment...
if not exist "venv\Scripts\activate.bat" (
    echo Virtual environment not found. Creating...
    python -m venv venv
    if ERRORLEVEL 1 (
        echo ERROR: Failed to create virtual environment!
        echo Make sure you have the 'venv' module installed.
        call :pause_with_message
    ) else (
        echo Virtual environment created successfully.
    )
)

:: Activate virtual environment
echo.
echo Activating virtual environment...
call venv\Scripts\activate.bat
if ERRORLEVEL 1 (
    echo ERROR: Failed to activate virtual environment!
    call :pause_with_message
) else (
    echo Virtual environment activated successfully.
)

:: Install dependencies
echo.
echo Checking dependencies...
if exist requirements.txt (
    echo Installing/updating dependencies...
    python -m pip install --upgrade pip
    if ERRORLEVEL 1 (
        echo ERROR: Failed to upgrade pip!
        call :pause_with_message
    )

    python -m pip install -r requirements.txt
    if ERRORLEVEL 1 (
        echo ERROR: Failed to install dependencies!
        echo Check if requirements.txt is properly formatted.
        call :pause_with_message
    ) else {
        echo Dependencies installed successfully.
    }
) else (
    echo WARNING: requirements.txt not found!
    echo Make sure all necessary dependencies are installed.
    call :pause_with_message
)

:: Final confirmation before starting the bot
echo.
echo ========================================================
echo All checks completed. Ready to start the bot.
echo The bot will run in this window.
echo To stop the bot, press Ctrl+C
echo ========================================================
echo.
echo Press any key to start the bot...
pause > nul

:: Run the bot directly in this window
echo.
echo Starting Telegram Forwarder Bot...
echo Bot output:
echo ========================================================
echo.
python forwarder.py

:: This will only execute if the bot exits
echo.
echo ========================================================
echo The bot has stopped running.
echo Check the above output for any errors.
echo ========================================================
echo.
echo Press any key to exit...
pause > nul