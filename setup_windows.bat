@echo off
setlocal enabledelayedexpansion

echo ======================================================
echo Установка и настройка Telegram Forwarder Bot (Windows)
echo ======================================================
echo.

:: Проверка наличия административных прав
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [!] Ошибка: Этот скрипт требует запуска с правами администратора.
    echo [!] Пожалуйста, запустите командную строку от имени администратора и повторите попытку.
    pause
    exit /b 1
)

:: Создание структуры проекта
echo [+] Создание структуры проекта...
mkdir "telegram-forwarder" 2>nul
cd "telegram-forwarder"
mkdir "logs" 2>nul

:: Проверка наличия Python и установка если не найден
where python >nul 2>&1
if %errorLevel% neq 0 (
    echo [+] Python не найден. Установка Python 3.12...

    :: Скачивание установщика Python
    echo [+] Скачивание установщика Python...
    powershell -Command "& {Invoke-WebRequest -Uri 'https://www.python.org/ftp/python/3.12.0/python-3.12.0-amd64.exe' -OutFile 'python-installer.exe'}"

    if not exist "python-installer.exe" (
        echo [!] Ошибка при скачивании установщика Python.
        exit /b 1
    )

    :: Установка Python
    echo [+] Установка Python 3.12...
    start /wait python-installer.exe /quiet InstallAllUsers=1 PrependPath=1 Include_test=0

    :: Проверка успешности установки
    where python >nul 2>&1
    if %errorLevel% neq 0 (
        echo [!] Ошибка при установке Python. Пожалуйста, установите Python 3.12 вручную.
        exit /b 1
    else
        echo [+] Python 3.12 успешно установлен.
    )

    :: Удаление установщика
    del python-installer.exe
) else (
    echo [+] Python уже установлен. Проверка версии...
    for /f "tokens=2" %%i in ('python --version 2^>^&1') do set pyver=%%i
    echo [+] Текущая версия Python: !pyver!
)

:: Создание требуемых файлов
echo [+] Создание конфигурационного файла...
echo [Telegram] > config.ini
echo api_id = 12345678 >> config.ini
echo api_hash = your_api_hash_here >> config.ini
echo target_channel_id = -1001234567890 >> config.ini
echo. >> config.ini
echo [Sources] >> config.ini
echo source_channel_names = -1001987654321 >> config.ini
echo min_delay = 1 >> config.ini
echo max_delay = 2 >> config.ini
echo jitter_range = 0.2 >> config.ini

echo [+] Создание файла requirements.txt...
echo telethon==1.32.1 > requirements.txt
echo python-dateutil==2.8.2 >> requirements.txt
echo asyncio==3.4.3 >> requirements.txt

echo [+] Создание основного скрипта бота...
(
echo import asyncio
echo import configparser
echo import random
echo import re
echo import logging
echo import os
echo import sys
echo import time
echo from datetime import datetime
echo from telethon import TelegramClient, events
echo from telethon.tl.types import MessageEntityUrl, MessageEntityTextUrl
echo.
echo # Настройка логгирования
echo log_dir = "logs"
echo if not os.path.exists^(log_dir^):
echo     os.makedirs^(log_dir^)
echo.
echo log_filename = f"{log_dir}/forwarder_{datetime.now^(^).strftime^('%%Y-%%m-%%d'^)}.log"
echo.
echo logging.basicConfig^(
echo     level=logging.INFO,
echo     format='%%(asctime^)s - %%(name^)s - %%(levelname^)s - %%(message^)s',
echo     handlers=[
echo         logging.FileHandler^(log_filename^),
echo         logging.StreamHandler^(sys.stdout^)
echo     ]
echo ^)
echo.
echo logger = logging.getLogger^('telegram_forwarder'^)
echo.
echo # Чтение конфигурационного файла
echo logger.info^("Чтение конфигурационного файла"^)
echo config = configparser.ConfigParser^(^)
echo try:
echo     config.read^('config.ini'^)
echo     logger.info^("Конфигурационный файл успешно прочитан"^)
echo except Exception as e:
echo     logger.error^(f"Ошибка при чтении конфигурационного файла: {e}"^)
echo     sys.exit^(1^)
echo.
echo # Telegram API данные
echo try:
echo     api_id = int^(config['Telegram']['api_id']^)
echo     api_hash = config['Telegram']['api_hash']
echo     target_channel_id = int^(config['Telegram']['target_channel_id']^)
echo     logger.info^(f"API данные получены. Целевой канал: {target_channel_id}"^)
echo except Exception as e:
echo     logger.error^(f"Ошибка при получении API данных: {e}"^)
echo     sys.exit^(1^)
echo.
echo # Настройки источников
echo try:
echo     source_channels = [int^(channel.strip^(^)^) for channel in config['Sources']['source_channel_names'].split^(','^)]
echo     min_delay = float^(config['Sources']['min_delay']^)
echo     max_delay = float^(config['Sources']['max_delay']^)
echo     jitter_range = float^(config['Sources']['jitter_range']^)
echo     logger.info^(f"Настройки источников получены. Каналы: {source_channels}"^)
echo     logger.info^(f"Настройки задержки: min={min_delay}, max={max_delay}, jitter={jitter_range}"^)
echo except Exception as e:
echo     logger.error^(f"Ошибка при получении настроек источников: {e}"^)
echo     sys.exit^(1^)
echo.
echo # Инициализация клиента
echo logger.info^("Инициализация Telegram клиента"^)
echo client = TelegramClient^('forwarder_session', api_id, api_hash^)
echo.
echo # Счетчики для статистики
echo message_counter = 0
echo error_counter = 0
echo start_time = time.time^(^)
echo.
echo # Функция для удаления ссылок из сообщения
echo async def remove_links^(message^):
echo     logger.info^("Начало обработки сообщения для удаления ссылок"^)
echo
echo     link_count = 0
echo     if message.text:
echo         # Создаем копию текста сообщения
echo         original_text = message.text
echo         new_text = original_text
echo
echo         # Если есть entities, обрабатываем их в обратном порядке ^(чтобы не сбить индексы^)
echo         if message.entities:
echo             link_entities = [entity for entity in message.entities
echo                              if isinstance^(entity, ^(MessageEntityUrl, MessageEntityTextUrl^)^)]
echo
echo             link_count = len^(link_entities^)
echo             if link_count ^> 0:
echo                 logger.info^(f"Найдено {link_count} ссылок в entities"^)
echo
echo                 # Сортируем entities в обратном порядке по позиции
echo                 link_entities.sort^(key=lambda e: e.offset, reverse=True^)
echo
echo                 # Удаляем ссылки из текста
echo                 for entity in link_entities:
echo                     start = entity.offset
echo                     end = start + entity.length
echo                     link_text = new_text[start:end]
echo                     logger.debug^(f"Удаление ссылки с позиции {start}-{end}: {link_text}"^)
echo                     new_text = new_text[:start] + new_text[end:]
echo
echo         # Дополнительная проверка на URL-ы с помощью регулярных выражений
echo
echo         # Шаблон для полных URL-адресов ^(http://, https://, www.^)
echo         full_url_pattern = re.compile^(r'https?://\S+^|www\.\S+'^)
echo
echo         # Шаблон для обнаружения "https://" и "http://" без остальной части URL
echo         partial_url_pattern = re.compile^(r'https?://\s*'^)
echo
echo         # Поиск и удаление полных URL
echo         urls = full_url_pattern.findall^(new_text^)
echo         if urls:
echo             logger.info^(f"Найдено {len^(urls^)} полных URL через регулярное выражение"^)
echo             for url in urls:
echo                 logger.debug^(f"Удаление URL: {url}"^)
echo             link_count += len^(urls^)
echo             new_text = full_url_pattern.sub^('', new_text^)
echo
echo         # Поиск и удаление префиксов URL ^(https://, http://^)
echo         partial_urls = partial_url_pattern.findall^(new_text^)
echo         if partial_urls:
echo             logger.info^(f"Найдено {len^(partial_urls^)} префиксов URL"^)
echo             for url in partial_urls:
echo                 logger.debug^(f"Удаление префикса URL: {url}"^)
echo             link_count += len^(partial_urls^)
echo             new_text = partial_url_pattern.sub^('', new_text^)
echo
echo         # Обновляем текст сообщения
echo         if original_text != new_text:
echo             logger.info^(f"Текст сообщения изменен. Удалено {link_count} ссылок/префиксов"^)
echo             logger.debug^(f"Исходный текст: {original_text}"^)
echo             logger.debug^(f"Новый текст: {new_text}"^)
echo         else:
echo             logger.info^("Текст сообщения не изменен ^(ссылок не найдено^)"^)
echo
echo         message.text = new_text
echo         message.entities = None  # Удаляем все entities, так как мы изменили текст
echo     else:
echo         logger.info^("Сообщение не содержит текста, только медиа"^)
echo
echo     return message, link_count
echo.
echo # Добавляем случайную задержку для более естественного поведения
echo async def random_delay^(^):
echo     base_delay = random.uniform^(min_delay, max_delay^)
echo     jitter = random.uniform^(-jitter_range, jitter_range^)
echo     delay = base_delay + ^(base_delay * jitter^)
echo     logger.info^(f"Добавлена случайная задержка: {delay:.2f} секунд"^)
echo     await asyncio.sleep^(delay^)
echo.
echo # Обработчик для новых сообщений в исходном канале
echo @client.on^(events.NewMessage^(chats=source_channels^)^)
echo async def forward_handler^(event^):
echo     global message_counter, error_counter
echo
echo     try:
echo         source_channel_id = event.chat_id
echo         message_id = event.message.id
echo         logger.info^(f"Получено новое сообщение из канала {source_channel_id}, ID сообщения: {message_id}"^)
echo
echo         # Добавляем случайную задержку перед пересылкой
echo         await random_delay^(^)
echo
echo         # Получаем сообщение
echo         message = event.message
echo
echo         # Логгируем информацию о медиа
echo         has_media = message.media is not None
echo         media_type = type^(message.media^).__name__ if has_media else "Нет"
echo         logger.info^(f"Тип медиа в сообщении: {media_type}"^)
echo
echo         # Удаляем ссылки
echo         message, removed_links = await remove_links^(message^)
echo
echo         # Если после удаления ссылок текст пустой, но есть медиа, то просто пересылаем медиа
echo         send_start_time = time.time^(^)
echo         if ^(not message.text or message.text.strip^(^) == ''^^^) and message.media:
echo             logger.info^("Пересылка только медиа без текста"^)
echo             await client.send_file^(
echo                 target_channel_id,
echo                 message.media,
echo                 caption=None
echo             ^)
echo         # Иначе пересылаем обычное сообщение или сообщение с медиа и текстом
echo         else:
echo             text_length = len^(message.text^) if message.text else 0
echo             logger.info^(f"Пересылка сообщения с текстом ^({text_length} символов^) {' и медиа' if has_media else ''}"^)
echo             await client.send_message^(
echo                 target_channel_id,
echo                 message.text,
echo                 file=message.media,
echo                 formatting_entities=message.entities
echo             ^)
echo
echo         send_time = time.time^(^) - send_start_time
echo         message_counter += 1
echo         uptime = time.time^(^) - start_time
echo
echo         logger.info^(f"Сообщение успешно переслано в канал {target_channel_id} за {send_time:.2f} секунд"^)
echo         logger.info^(f"Статистика: обработано {message_counter} сообщений, {error_counter} ошибок, время работы: {uptime/60:.2f} минут"^)
echo
echo     except Exception as e:
echo         error_counter += 1
echo         logger.error^(f"Ошибка при пересылке сообщения: {e}", exc_info=True^)
echo.
echo # Функция для вывода статистики каждый час
echo async def print_stats^(^):
echo     while True:
echo         await asyncio.sleep^(3600^)  # Каждый час
echo         uptime = time.time^(^) - start_time
echo         success_rate = ^(message_counter / ^(message_counter + error_counter^)^) * 100 if ^(message_counter + error_counter^) ^> 0 else 0
echo
echo         logger.info^("=" * 50^)
echo         logger.info^("СТАТИСТИКА"^)
echo         logger.info^(f"Время работы: {uptime/3600:.2f} часов"^)
echo         logger.info^(f"Обработано сообщений: {message_counter}"^)
echo         logger.info^(f"Ошибок: {error_counter}"^)
echo         logger.info^(f"Успешность: {success_rate:.2f}%%"^)
echo         logger.info^("=" * 50^)
echo.
echo # Запуск бота
echo async def main^(^):
echo     logger.info^("=" * 50^)
echo     logger.info^("ЗАПУСК БОТА ДЛЯ ПЕРЕСЫЛКИ СООБЩЕНИЙ ИЗ TELEGRAM"^)
echo     logger.info^(f"Дата и время запуска: {datetime.now^(^).strftime^('%%Y-%%m-%%d %%H:%%M:%%S'^)}"^)
echo     logger.info^(f"Отслеживаемые каналы: {source_channels}"^)
echo     logger.info^(f"Целевой канал: {target_channel_id}"^)
echo     logger.info^("=" * 50^)
echo
echo     try:
echo         # Запускаем клиент
echo         await client.start^(^)
echo         logger.info^("Telegram клиент успешно запущен и авторизован"^)
echo
echo         # Запускаем задачу статистики
echo         asyncio.create_task^(print_stats^(^)^)
echo
echo         # Держим клиент активным
echo         await client.run_until_disconnected^(^)
echo     except Exception as e:
echo         logger.critical^(f"Критическая ошибка: {e}", exc_info=True^)
echo     finally:
echo         logger.info^("Завершение работы бота"^)
echo.
echo # Запуск основной функции
echo if __name__ == "__main__":
echo     try:
echo         asyncio.run^(main^(^)^)
echo     except KeyboardInterrupt:
echo         logger.info^("Бот остановлен пользователем ^(Ctrl+C^)"^)
echo     except Exception as e:
echo         logger.critical^(f"Необработанное исключение: {e}", exc_info=True^)
) > forwarder.py

echo [+] Создание файла для запуска бота...
echo @echo off > start_bot.bat
echo echo Запуск Telegram Forwarder Bot... >> start_bot.bat
echo cd /d %%~dp0 >> start_bot.bat
echo python -m pip install -r requirements.txt >> start_bot.bat
echo python forwarder.py >> start_bot.bat
echo pause >> start_bot.bat

echo [+] Создание файла для запуска бота как службы (для опытных пользователей)...
(
echo @echo off
echo echo Создание и запуск службы Telegram Forwarder Bot
echo echo Этот скрипт требует запуска от имени администратора.
echo echo.
echo.
echo cd /d %%~dp0
echo.
echo REM Проверка наличия nssm.exe
echo if not exist "nssm.exe" ^(
echo     echo Скачивание NSSM ^(Non-Sucking Service Manager^)...
echo     powershell -Command "& {Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile 'nssm.zip'}"
echo     echo Распаковка NSSM...
echo     powershell -Command "& {Expand-Archive -Path 'nssm.zip' -DestinationPath '.' -Force}"
echo     copy "nssm-2.24\win64\nssm.exe" "." /Y
echo     rd /s /q "nssm-2.24"
echo     del "nssm.zip"
echo ^)
echo.
echo REM Остановка службы, если она уже существует
echo nssm stop TelegramForwarder
echo nssm remove TelegramForwarder confirm
echo.
echo REM Создание новой службы
echo set PYTHONPATH=%%~dp0
echo nssm install TelegramForwarder "%%~dp0venv\Scripts\python.exe" "%%~dp0forwarder.py"
echo nssm set TelegramForwarder AppDirectory "%%~dp0"
echo nssm set TelegramForwarder DisplayName "Telegram Forwarder Bot"
echo nssm set TelegramForwarder Description "Бот для пересылки сообщений из Telegram каналов"
echo nssm set TelegramForwarder Start SERVICE_AUTO_START
echo nssm set TelegramForwarder AppStdout "%%~dp0logs\service.log"
echo nssm set TelegramForwarder AppStderr "%%~dp0logs\service.log"
echo nssm set TelegramForwarder AppStopMethodConsole 3000
echo.
echo REM Запуск службы
echo nssm start TelegramForwarder
echo.
echo echo Служба установлена и запущена. Проверьте папку logs для отслеживания работы бота.
echo echo Вы можете управлять службой через стандартный интерфейс служб Windows.
echo pause
) > install_as_service.bat

:: Создание виртуального окружения
echo [+] Создание виртуального окружения...
python -m venv venv
call venv\Scripts\activate.bat

:: Установка зависимостей
echo [+] Установка зависимостей...
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

:: Создание README.md
echo [+] Создание файла README.md...
(
echo # Telegram Forwarder Bot
echo.
echo ## Установка и настройка ^(Windows^)
echo.
echo ### Автоматическая установка
echo.
echo 1. Запустите файл `setup_windows.bat` от имени администратора.
echo 2. Скрипт автоматически установит Python, создаст виртуальное окружение и установит все необходимые зависимости.
echo 3. Отредактируйте файл `config.ini`, указав ваши данные:
echo    - `api_id` и `api_hash` - данные вашего Telegram приложения
echo    - `target_channel_id` - ID вашего целевого канала
echo    - `source_channel_names` - ID исходных каналов ^(через запятую^)
echo 4. Запустите бота с помощью файла `start_bot.bat`.
echo.
echo ### Запуск в фоновом режиме ^(как служба Windows^)
echo.
echo Для запуска бота как службы Windows:
echo.
echo 1. Запустите файл `install_as_service.bat` от имени администратора.
echo 2. Скрипт установит и запустит бота как службу Windows.
echo 3. Логи службы будут доступны в папке `logs`.
echo.
echo ## Использование
echo.
echo 1. При первом запуске вам потребуется авторизоваться в Telegram, введя номер телефона и код подтверждения.
echo 2. После успешной авторизации бот будет автоматически пересылать сообщения из указанных каналов в ваш целевой канал.
echo 3. Бот автоматически фильтрует все ссылки в пересылаемых сообщениях.
echo.
echo ## Решение проблем
echo.
echo - Если бот не запускается, проверьте файлы логов в папке `logs`.
echo - При проблемах с авторизацией удалите файл `forwarder_session.session` и запустите бота заново.
) > README.md

:: Инструкции для пользователя
echo.
echo [+] Установка завершена успешно!
echo.
echo [+] Что дальше:
echo [1] Отредактируйте файл config.ini, указав ваши данные Telegram:
echo     - api_id и api_hash: получите на my.telegram.org (API development tools)
echo     - target_channel_id: ID вашего целевого канала
echo     - source_channel_names: ID исходных каналов (через запятую)
echo.
echo [2] Запустите бота с помощью файла start_bot.bat
echo     При первом запуске вам потребуется авторизоваться в Telegram.
echo.
echo [3] Для запуска бота как службы Windows используйте install_as_service.bat
echo     (требуются права администратора)
echo.
echo [+] Документация доступна в файле README.md
echo.
pause