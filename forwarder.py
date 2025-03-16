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