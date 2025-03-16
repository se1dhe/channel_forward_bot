#!/usr/bin/env python3
import os
import sys
import shutil
import configparser
from pathlib import Path


def print_banner():
    banner = """
    ╔════════════════════════════════════════════╗
    ║             TELEGRAM FORWARDER             ║
    ║      Установка и настройка бота для        ║
    ║       пересылки сообщений из каналов       ║
    ╚════════════════════════════════════════════╝
    """
    print(banner)


def check_python_version():
    print("[+] Проверка версии Python...")
    if sys.version_info.major < 3 or (sys.version_info.major == 3 and sys.version_info.minor < 6):
        print("[-] Ошибка: Требуется Python версии 3.6 или выше")
        print(f"[-] Ваша версия: {sys.version}")
        sys.exit(1)
    print(f"[+] Проверка пройдена. Версия Python: {sys.version}")


def create_directory_structure():
    print("[+] Создание структуры каталогов...")

    directories = ["logs"]

    for directory in directories:
        if not os.path.exists(directory):
            os.makedirs(directory)
            print(f"[+] Создан каталог: {directory}")
        else:
            print(f"[*] Каталог уже существует: {directory}")


def check_config_file():
    print("[+] Проверка конфигурационного файла...")
    config_path = Path("config.ini")

    if not config_path.exists():
        print("[-] Конфигурационный файл config.ini не найден")
        create_sample_config = input("[?] Создать пример конфигурационного файла? (y/n): ")

        if create_sample_config.lower() == 'y':
            create_sample_config_file()
            print("[+] Создан пример конфигурационного файла config.ini")
            print("[!] Важно: Отредактируйте config.ini перед запуском бота")
            return False
        else:
            print("[-] Пожалуйста, создайте конфигурационный файл config.ini вручную")
            return False

    # Проверка содержимого файла
    try:
        config = configparser.ConfigParser()
        config.read('config.ini')

        # Проверка необходимых секций и параметров
        if not ('Telegram' in config and 'Sources' in config):
            print("[-] Ошибка: В конфигурационном файле отсутствуют необходимые секции")
            return False

        required_telegram_params = ['api_id', 'api_hash', 'target_channel_id']
        required_sources_params = ['source_channel_names', 'min_delay', 'max_delay', 'jitter_range']

        for param in required_telegram_params:
            if param not in config['Telegram']:
                print(f"[-] Ошибка: В секции [Telegram] отсутствует параметр {param}")
                return False

        for param in required_sources_params:
            if param not in config['Sources']:
                print(f"[-] Ошибка: В секции [Sources] отсутствует параметр {param}")
                return False

        print("[+] Конфигурационный файл существует и содержит необходимые параметры")
        return True

    except Exception as e:
        print(f"[-] Ошибка при чтении конфигурационного файла: {e}")
        return False


def create_sample_config_file():
    config = configparser.ConfigParser()

    config['Telegram'] = {
        'api_id': '123456',  # Замените на ваш api_id
        'api_hash': 'abcdef1234567890abcdef',  # Замените на ваш api_hash
        'target_channel_id': '-1001234567890'  # ID канала, куда пересылать сообщения
    }

    config['Sources'] = {
        'source_channel_names': '-1001234567890',  # ID канала-источника
        'min_delay': '1',  # Минимальная задержка между пересылками (в секундах)
        'max_delay': '2',  # Максимальная задержка между пересылками (в секундах)
        'jitter_range': '0.2'  # Диапазон случайной вариации задержки
    }

    with open('config.ini', 'w') as configfile:
        config.write(configfile)


def install_requirements():
    print("[+] Установка зависимостей...")

    if not os.path.exists('requirements.txt'):
        print("[-] Файл requirements.txt не найден")
        create_requirements = input("[?] Создать файл requirements.txt? (y/n): ")

        if create_requirements.lower() == 'y':
            with open('requirements.txt', 'w') as f:
                f.write("telethon==1.32.1\n")
                f.write("python-dateutil==2.8.2\n")
                f.write("asyncio==3.4.3\n")
            print("[+] Файл requirements.txt создан")
        else:
            print("[-] Пропуск установки зависимостей")
            return

    try:
        os.system(f"{sys.executable} -m pip install -r requirements.txt")
        print("[+] Зависимости успешно установлены")
    except Exception as e:
        print(f"[-] Ошибка при установке зависимостей: {e}")


def create_main_script():
    print("[+] Создание основного скрипта бота...")

    if os.path.exists('forwarder.py'):
        overwrite = input("[?] Файл forwarder.py уже существует. Перезаписать? (y/n): ")
        if overwrite.lower() != 'y':
            print("[*] Пропуск создания основного скрипта")
            return

    script_content = """
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

        # Дополнительная проверка на URL-ы с помощью регулярного выражения
        url_pattern = re.compile(r'https?://\S+|www\.\S+')
        urls = url_pattern.findall(new_text)
        if urls:
            logger.info(f"Найдено {len(urls)} дополнительных URL через регулярное выражение")
            for url in urls:
                logger.debug(f"Удаление URL: {url}")
            link_count += len(urls)
            new_text = url_pattern.sub('', new_text)

        # Обновляем текст сообщения
        if original_text != new_text:
            logger.info(f"Текст сообщения изменен. Удалено {link_count} ссылок")
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
"""

    with open('forwarder.py', 'w') as f:
        f.write(script_content.strip())

    # Сделать скрипт исполняемым
    os.chmod('forwarder.py', 0o755)

    print("[+] Основной скрипт forwarder.py создан")


def create_readme():
    print("[+] Создание README.md...")

    readme_content = """# Telegram Forwarder Bot

## 📝 Описание

Этот скрипт создает Telegram юзер-бота для автоматической пересылки сообщений из одного канала в другой с фильтрацией нежелательного контента. Бот является полностью настраиваемым и поддерживает различные типы медиа-сообщений (фото, видео, голосовые сообщения).

### 🔑 Основные возможности:

- Пересылка сообщений из закрытых каналов в ваш канал
- Фильтрация ссылок из пересылаемых сообщений
- Сохранение форматирования сообщений
- Поддержка различных типов медиа (фото, видео, голосовые сообщения)
- Случайные задержки между пересылками для более естественного поведения
- Подробное логгирование действий для отслеживания работы
- Вывод статистики работы

## 🛠️ Установка и настройка

### Предварительные требования

- Python 3.6 или выше
- Зарегистрированное приложение Telegram (для получения `api_id` и `api_hash`)
- Доступ к исходному каналу
- Права администратора в целевом канале

### Шаг 1: Получение API данных Telegram

1. Перейдите на [my.telegram.org](https://my.telegram.org) и войдите в свой аккаунт
2. Перейдите в раздел "API development tools"
3. Создайте новое приложение
4. Скопируйте `api_id` и `api_hash` для использования в конфигурационном файле

### Шаг 2: Установка

1. Клонируйте репозиторий или скачайте все файлы в отдельную папку
2. Запустите скрипт установки:
   ```
   python setup.py
   ```

   Скрипт автоматически:
   - Проверит версию Python
   - Создаст необходимую структуру каталогов
   - Проверит или создаст конфигурационный файл
   - Установит необходимые зависимости
   - Подготовит основной скрипт бота

3. Настройте конфигурационный файл `config.ini` (см. раздел ниже)

### Шаг 3: Настройка

Отредактируйте файл `config.ini` в соответствии с вашими потребностями:

```ini
[Telegram]
api_id = ваш_api_id
api_hash = ваш_api_hash
target_channel_id = id_целевого_канала

[Sources]
source_channel_names = id_исходного_канала_1, id_исходного_канала_2
min_delay = 1
max_delay = 2
jitter_range = 0.2
```

#### Пояснения к параметрам:

- `api_id` и `api_hash` - данные вашего Telegram приложения
- `target_channel_id` - ID канала, куда будут пересылаться сообщения
- `source_channel_names` - ID каналов, откуда будут браться сообщения (можно указать несколько через запятую)
- `min_delay` и `max_delay` - минимальная и максимальная задержка между пересылками в секундах
- `jitter_range` - диапазон случайной вариации задержки

> **Важно**: ID каналов следует указывать с минусом в начале, например: `-1001234567890`

### Шаг 4: Запуск

Запустите бота командой:

```
python forwarder.py
```

При первом запуске вам будет предложено войти в свой аккаунт Telegram, следуйте инструкциям на экране.

## 🔍 Мониторинг работы

Бот создает подробные логи в директории `logs/`. Файлы логов создаются для каждого дня работы и содержат информацию о:

- Полученных сообщениях
- Удаленных ссылках
- Пересланных сообщениях
- Возникших ошибках
- Статистике работы

## 📊 Статистика

Бот каждый час выводит в лог следующую статистику:

- Время работы
- Количество обработанных сообщений
- Количество ошибок
- Процент успешных пересылок

## ⚠️ Важные замечания

1. Использование юзер-ботов может противоречить условиям использования Telegram. Используйте на свой страх и риск.
2. Не рекомендуется устанавливать слишком маленькие задержки между пересылками, это может привести к ограничениям со стороны Telegram.
3. Регулярно проверяйте логи для отслеживания возможных проблем.

## 🔧 Устранение неполадок

### Бот не авторизуется

Удалите файл `forwarder_session.session` и запустите бота заново для повторной авторизации.

### Ошибки при пересылке медиа

Проверьте, что у вас есть права на пересылку сообщений из исходного канала и на публикацию в целевом канале.

### Другие проблемы

Проверьте файлы логов в директории `logs/` для получения подробной информации об ошибках.

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. Подробности см. в файле LICENSE.
"""

    with open('README.md', 'w') as f:
        f.write(readme_content)

    print("[+] Файл README.md создан")


def main():
    print_banner()

    # Проверка версии Python
    check_python_version()

    # Создание структуры каталогов
    create_directory_structure()

    # Проверка/создание конфигурационного файла
    config_ok = check_config_file()

    # Установка зависимостей
    install_requirements()

    # Создание основного скрипта
    create_main_script()

    # Создание README
    create_readme()

    print("\n[+] Установка завершена!")

    if not config_ok:
        print("[!] Важно: Отредактируйте файл config.ini перед запуском бота")

    print("\n[+] Для запуска бота выполните команду:")
    print("    python forwarder.py")


if __name__ == "__main__":
    main()