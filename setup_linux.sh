#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}  Установка и настройка Telegram Forwarder Bot (Linux) ${NC}"
echo -e "${BLUE}======================================================${NC}"
echo ""

# Проверка наличия sudo прав
if [ "$(id -u)" != "0" ]; then
   echo -e "${YELLOW}[!] Этот скрипт должен быть запущен с правами sudo.${NC}"
   echo -e "${YELLOW}[!] Пожалуйста, запустите: sudo bash setup_linux.sh${NC}"
   exit 1
fi

# Проверка дистрибутива Linux
if [ -f /etc/os-release ]; then
    # freedesktop.org и systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    # Fall back to uname
    OS=$(uname -s)
    VER=$(uname -r)
fi

echo -e "${GREEN}[+] Обнаружена система: ${OS} ${VER}${NC}"

# Создание структуры проекта
echo -e "${GREEN}[+] Создание структуры проекта...${NC}"
mkdir -p telegram-forwarder/logs
# shellcheck disable=SC2164
cd telegram-forwarder

# Обновление системы и установка зависимостей
echo -e "${GREEN}[+] Обновление системы и установка необходимых пакетов...${NC}"

if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    apt-get update
    apt-get install -y software-properties-common python3-dev python3-pip python3-venv wget curl gnupg build-essential

    # Добавление репозитория для Python 3.12
    add-apt-repository -y ppa:deadsnakes/ppa
    apt-get update
    apt-get install -y python3.12 python3.12-venv python3.12-dev

elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Fedora"* ]]; then
    # Для RHEL/CentOS/Fedora
    yum -y update
    yum -y install gcc openssl-devel bzip2-devel libffi-devel wget make

    # Установка Python 3.12 из исходников
    echo -e "${GREEN}[+] Установка Python 3.12 из исходников...${NC}"
    wget https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tgz
    tar xzf Python-3.12.0.tgz
    cd Python-3.12.0
    ./configure --enable-optimizations
    make altinstall
    cd ..
    rm -rf Python-3.12.0*
    ln -sf /usr/local/bin/python3.12 /usr/bin/python3.12

elif [[ "$OS" == *"Arch"* ]]; then
    # Для Arch Linux
    pacman -Syu --noconfirm
    pacman -S --noconfirm python python-pip gcc
else
    echo -e "${YELLOW}[!] Не удалось определить дистрибутив. Проверьте, что Python 3.12 установлен вручную.${NC}"
fi

# Проверка установки Python 3.12
if command -v python3.12 &>/dev/null; then
    echo -e "${GREEN}[+] Python 3.12 успешно установлен.${NC}"
    PYTHON_CMD="python3.12"
elif command -v python3 &>/dev/null; then
    echo -e "${YELLOW}[!] Python 3.12 не найден, будет использован Python 3.${NC}"
    PYTHON_CMD="python3"
else
    echo -e "${RED}[!] Python 3 не найден. Пожалуйста, установите Python 3 вручную.${NC}"
    exit 1
fi

# Вывод версии Python
echo -e "${GREEN}[+] Текущая версия Python:${NC}"
$PYTHON_CMD --version

# Создание виртуального окружения
echo -e "${GREEN}[+] Создание виртуального окружения...${NC}"
$PYTHON_CMD -m venv venv
source venv/bin/activate

# Создание требуемых файлов
echo -e "${GREEN}[+] Создание конфигурационного файла...${NC}"
cat > config.ini << EOL
[Telegram]
api_id = 12345678
api_hash = your_api_hash_here
target_channel_id = -1001234567890

[Sources]
source_channel_names = -1001987654321
min_delay = 1
max_delay = 2
jitter_range = 0.2
EOL

echo -e "${GREEN}[+] Создание файла requirements.txt...${NC}"
cat > requirements.txt << EOL
telethon==1.32.1
python-dateutil==2.8.2
asyncio==3.4.3
EOL

echo -e "${GREEN}[+] Создание основного скрипта бота...${NC}"
cat > forwarder.py << 'EOL'
import asyncio
import configparser
import random
import re
import logging
import os
import sys
import time
from datetime import datetime
from telethon import TelegramClient, events
from telethon.tl.types import MessageEntityUrl, MessageEntityTextUrl

# Настройка логгирования
log_dir = "logs"
if not os.path.exists(log_dir):
    os.makedirs(log_dir)

log_filename = f"{log_dir}/forwarder_{datetime.now().strftime('%Y-%m-%d')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_filename),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger('telegram_forwarder')

# Чтение конфигурационного файла
logger.info("Чтение конфигурационного файла")
config = configparser.ConfigParser()
try:
    config.read('config.ini')
    logger.info("Конфигурационный файл успешно прочитан")
except Exception as e:
    logger.error(f"Ошибка при чтении конфигурационного файла: {e}")
    sys.exit(1)

# Telegram API данные
try:
    api_id = int(config['Telegram']['api_id'])
    api_hash = config['Telegram']['api_hash']
    target_channel_id = int(config['Telegram']['target_channel_id'])
    logger.info(f"API данные получены. Целевой канал: {target_channel_id}")
except Exception as e:
    logger.error(f"Ошибка при получении API данных: {e}")
    sys.exit(1)

# Настройки источников
try:
    source_channels = [int(channel.strip()) for channel in config['Sources']['source_channel_names'].split(',')]
    min_delay = float(config['Sources']['min_delay'])
    max_delay = float(config['Sources']['max_delay'])
    jitter_range = float(config['Sources']['jitter_range'])
    logger.info(f"Настройки источников получены. Каналы: {source_channels}")
    logger.info(f"Настройки задержки: min={min_delay}, max={max_delay}, jitter={jitter_range}")
except Exception as e:
    logger.error(f"Ошибка при получении настроек источников: {e}")
    sys.exit(1)

# Инициализация клиента
logger.info("Инициализация Telegram клиента")
client = TelegramClient('forwarder_session', api_id, api_hash)

# Счетчики для статистики
message_counter = 0
error_counter = 0
start_time = time.time()

# Функция для удаления ссылок из сообщения
async def remove_links(message):
    logger.info("Начало обработки сообщения для удаления ссылок")

    link_count = 0
    if message.text:
        # Создаем копию текста сообщения
        original_text = message.text
        new_text = original_text

        # Если есть entities, обрабатываем их в обратном порядке (чтобы не сбить индексы)
        if message.entities:
            link_entities = [entity for entity in message.entities
                             if isinstance(entity, (MessageEntityUrl, MessageEntityTextUrl))]

            link_count = len(link_entities)
            if link_count > 0:
                logger.info(f"Найдено {link_count} ссылок в entities")

                # Сортируем entities в обратном порядке по позиции
                link_entities.sort(key=lambda e: e.offset, reverse=True)

                # Удаляем ссылки из текста
                for entity in link_entities:
                    start = entity.offset
                    end = start + entity.length
                    link_text = new_text[start:end]
                    logger.debug(f"Удаление ссылки с позиции {start}-{end}: {link_text}")
                    new_text = new_text[:start] + new_text[end:]

        # Дополнительная проверка на URL-ы с помощью регулярных выражений

        # Шаблон для полных URL-адресов (http://, https://, www.)
        full_url_pattern = re.compile(r'https?://\S+|www\.\S+')

        # Шаблон для обнаружения "https://" и "http://" без остальной части URL
        partial_url_pattern = re.compile(r'https?://\s*')

        # Поиск и удаление полных URL
        urls = full_url_pattern.findall(new_text)
        if urls:
            logger.info(f"Найдено {len(urls)} полных URL через регулярное выражение")
            for url in urls:
                logger.debug(f"Удаление URL: {url}")
            link_count += len(urls)
            new_text = full_url_pattern.sub('', new_text)

        # Поиск и удаление префиксов URL (https://, http://)
        partial_urls = partial_url_pattern.findall(new_text)
        if partial_urls:
            logger.info(f"Найдено {len(partial_urls)} префиксов URL")
            for url in partial_urls:
                logger.debug(f"Удаление префикса URL: {url}")
            link_count += len(partial_urls)
            new_text = partial_url_pattern.sub('', new_text)

        # Обновляем текст сообщения
        if original_text != new_text:
            logger.info(f"Текст сообщения изменен. Удалено {link_count} ссылок/префиксов")
            logger.debug(f"Исходный текст: {original_text}")
            logger.debug(f"Новый текст: {new_text}")
        else:
            logger.info("Текст сообщения не изменен (ссылок не найдено)")

        message.text = new_text
        message.entities = None  # Удаляем все entities, так как мы изменили текст
    else:
        logger.info("Сообщение не содержит текста, только медиа")

    return message, link_count

# Добавляем случайную задержку для более естественного поведения
async def random_delay():
    base_delay = random.uniform(min_delay, max_delay)
    jitter = random.uniform(-jitter_range, jitter_range)
    delay = base_delay + (base_delay * jitter)
    logger.info(f"Добавлена случайная задержка: {delay:.2f} секунд")
    await asyncio.sleep(delay)

# Обработчик для новых сообщений в исходном канале
@client.on(events.NewMessage(chats=source_channels))
async def forward_handler(event):
    global message_counter, error_counter

    try:
        source_channel_id = event.chat_id
        message_id = event.message.id
        logger.info(f"Получено новое сообщение из канала {source_channel_id}, ID сообщения: {message_id}")

        # Добавляем случайную задержку перед пересылкой
        await random_delay()

        # Получаем сообщение
        message = event.message

        # Логгируем информацию о медиа
        has_media = message.media is not None
        media_type = type(message.media).__name__ if has_media else "Нет"
        logger.info(f"Тип медиа в сообщении: {media_type}")

        # Удаляем ссылки
        message, removed_links = await remove_links(message)

        # Если после удаления ссылок текст пустой, но есть медиа, то просто пересылаем медиа
        send_start_time = time.time()
        if (not message.text or message.text.strip() == '') and message.media:
            logger.info("Пересылка только медиа без текста")
            await client.send_file(
                target_channel_id,
                message.media,
                caption=None
            )
        # Иначе пересылаем обычное сообщение или сообщение с медиа и текстом
        else:
            text_length = len(message.text) if message.text else 0
            logger.info(f"Пересылка сообщения с текстом ({text_length} символов) {' и медиа' if has_media else ''}")
            await client.send_message(
                target_channel_id,
                message.text,
                file=message.media,
                formatting_entities=message.entities
            )

        send_time = time.time() - send_start_time
        message_counter += 1
        uptime = time.time() - start_time

        logger.info(f"Сообщение успешно переслано в канал {target_channel_id} за {send_time:.2f} секунд")
        logger.info(f"Статистика: обработано {message_counter} сообщений, {error_counter} ошибок, время работы: {uptime/60:.2f} минут")

    except Exception as e:
        error_counter += 1
        logger.error(f"Ошибка при пересылке сообщения: {e}", exc_info=True)

# Функция для вывода статистики каждый час
async def print_stats():
    while True:
        await asyncio.sleep(3600)  # Каждый час
        uptime = time.time() - start_time
        success_rate = (message_counter / (message_counter + error_counter)) * 100 if (message_counter + error_counter) > 0 else 0

        logger.info("=" * 50)
        logger.info("СТАТИСТИКА")
        logger.info(f"Время работы: {uptime/3600:.2f} часов")
        logger.info(f"Обработано сообщений: {message_counter}")
        logger.info(f"Ошибок: {error_counter}")
        logger.info(f"Успешность: {success_rate:.2f}%")
        logger.info("=" * 50)

# Запуск бота
async def main():
    logger.info("=" * 50)
    logger.info("ЗАПУСК БОТА ДЛЯ ПЕРЕСЫЛКИ СООБЩЕНИЙ ИЗ TELEGRAM")
    logger.info(f"Дата и время запуска: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info(f"Отслеживаемые каналы: {source_channels}")
    logger.info(f"Целевой канал: {target_channel_id}")
    logger.info("=" * 50)

    try:
        # Запускаем клиент
        await client.start()
        logger.info("Telegram клиент успешно запущен и авторизован")

        # Запускаем задачу статистики
        asyncio.create_task(print_stats())

        # Держим клиент активным
        await client.run_until_disconnected()
    except Exception as e:
        logger.critical(f"Критическая ошибка: {e}", exc_info=True)
    finally:
        logger.info("Завершение работы бота")

# Запуск основной функции
if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Бот остановлен пользователем (Ctrl+C)")
    except Exception as e:
        logger.critical(f"Необработанное исключение: {e}", exc_info=True)
EOL

# Создание скрипта для запуска бота
echo -e "${GREEN}[+] Создание скрипта для запуска бота...${NC}"
cat > start_bot.sh << 'EOL'
#!/bin/bash
# Скрипт запуска Telegram Forwarder Bot

# Переходим в директорию скрипта
cd "$(dirname "$0")"

# Активация виртуального окружения
source venv/bin/activate

# Установка/обновление зависимостей
pip install -r requirements.txt

# Запуск бота
python forwarder.py
EOL

# Делаем скрипт запуска исполняемым
chmod +x start_bot.sh

# Создание systemd сервиса для запуска в фоновом режиме
echo -e "${GREEN}[+] Создание systemd сервиса...${NC}"
cat > telegram-forwarder.service << EOL
[Unit]
Description=Telegram Forwarder Bot
After=network.target

[Service]
Type=simple
User=$(logname)
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/venv/bin/python $(pwd)/forwarder.py
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL

# Создание README.md
echo -e "${GREEN}[+] Создание файла README.md...${NC}"
cat > README.md << 'EOL'
# Telegram Forwarder Bot

## Установка и настройка (Linux)

### Автоматическая установка

1. Скачайте скрипт установки:
   ```
   wget https://raw.githubusercontent.com/yourusername/telegram-forwarder/main/setup_linux.sh
   ```

2. Сделайте скрипт исполняемым:
   ```
   chmod +x setup_linux.sh
   ```

3. Запустите скрипт установки с правами sudo:
   ```
   sudo ./setup_linux.sh
   ```

4. Отредактируйте файл `config.ini`, указав ваши данные:
   - `api_id` и `api_hash` - данные вашего Telegram приложения
   - `target_channel_id` - ID вашего целевого канала
   - `source_channel_names` - ID исходных каналов (через запятую)

5. Запустите бота:
   ```
   ./start_bot.sh
   ```

### Запуск в фоновом режиме (как systemd сервис)

Для запуска бота как системной службы:

1. Установите службу:
   ```
   sudo cp telegram-forwarder.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable telegram-forwarder.service
   sudo systemctl start telegram-forwarder.service
   ```

2. Проверка статуса:
   ```
   sudo systemctl status telegram-forwarder.service
   ```

3. Просмотр логов:
   ```
   sudo journalctl -u telegram-forwarder.service -f
   ```

## Использование

1. При первом запуске вам потребуется авторизоваться в Telegram, введя номер телефона и код подтверждения.
2. После успешной авторизации бот будет автоматически пересылать сообщения из указанных каналов в ваш целевой канал.
3. Бот автоматически фильтрует все ссылки в пересылаемых сообщениях.

## Решение проблем

- Если бот не запускается, проверьте файлы логов в папке `logs`.
- При проблемах с авторизацией удалите файл `forwarder_session.session` и запустите бота заново.
- Для просмотра логов службы используйте: `sudo journalctl -u telegram-forwarder.service -f`
EOL

# Установка зависимостей
echo -e "${GREEN}[+] Установка зависимостей...${NC}"
pip install --upgrade pip
pip install -r requirements.txt

# Создание скрипта для установки системной службы
echo -e "${GREEN}[+] Создание скрипта для установки системной службы...${NC}"
cat > install_service.sh << 'EOL'
#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}==================================================${NC}"
echo -e "${BLUE}  Установка Telegram Forwarder Bot как службы      ${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Проверка наличия sudo прав
if [ "$(id -u)" != "0" ]; then
   echo -e "${YELLOW}[!] Этот скрипт должен быть запущен с правами sudo.${NC}"
   echo -e "${YELLOW}[!] Пожалуйста, запустите: sudo bash install_service.sh${NC}"
   exit 1
fi

# Путь к текущей директории
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Копирование файла службы
echo -e "${GREEN}[+] Установка systemd сервиса...${NC}"
cp "$SCRIPT_DIR/telegram-forwarder.service" /etc/systemd/system/
systemctl daemon-reload

# Включение и запуск службы
echo -e "${GREEN}[+] Включение и запуск службы...${NC}"
systemctl enable telegram-forwarder.service
systemctl start telegram-forwarder.service

# Проверка статуса
echo -e "${GREEN}[+] Проверка статуса службы...${NC}"
systemctl status telegram-forwarder.service

echo ""
echo -e "${GREEN}[+] Установка службы завершена!${NC}"
echo -e "${GREEN}[+] Теперь бот будет запускаться автоматически при загрузке системы.${NC}"
echo ""
echo -e "${BLUE}Полезные команды:${NC}"
echo -e "  ${YELLOW}sudo systemctl status telegram-forwarder.service${NC} - проверить статус"
echo -e "  ${YELLOW}sudo systemctl stop telegram-forwarder.service${NC} - остановить бота"
echo -e "  ${YELLOW}sudo systemctl start telegram-forwarder.service${NC} - запустить бота"
echo -e "  ${YELLOW}sudo systemctl restart telegram-forwarder.service${NC} - перезапустить бота"
echo -e "  ${YELLOW}sudo journalctl -u telegram-forwarder.service -f${NC} - просмотр логов в реальном времени"
EOL

# Делаем скрипт установки службы исполняемым
chmod +x install_service.sh

# Настройка прав доступа для текущего пользователя
current_user=$(logname)
chown -R $current_user:$current_user $(pwd)

# Завершение установки
echo -e "${GREEN}[+] Установка завершена успешно!${NC}"
echo ""
echo -e "${GREEN}[+] Что дальше:${NC}"
echo -e "${YELLOW}[1] Отредактируйте файл config.ini, указав ваши данные Telegram:${NC}"
echo -e "     - api_id и api_hash: получите на my.telegram.org (API development tools)"
echo -e "     - target_channel_id: ID вашего целевого канала"
echo -e "     - source_channel_names: ID исходных каналов (через запятую)"
echo ""
echo -e "${YELLOW}[2] Запустите бота с помощью:${NC}"
echo -e "     ./start_bot.sh"
echo -e "     При первом запуске вам потребуется авторизоваться в Telegram."
echo ""
echo -e "${YELLOW}[3] Для запуска бота как systemd службы используйте:${NC}"
echo -e "     sudo ./install_service.sh"
echo ""
echo -e "${GREEN}[+] Документация доступна в файле README.md${NC}"
echo ""

exit 0