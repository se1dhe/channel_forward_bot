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

# Logging setup
log_dir = "logs"
if not os.path.exists(log_dir):
    os.makedirs(log_dir)

log_filename = f"{log_dir}/forwarder_{datetime.now().strftime('%Y-%m-%d')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_filename, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger('telegram_forwarder')

# Reading configuration file
logger.info("Reading configuration file")
config = configparser.ConfigParser()
try:
    config.read('config.ini', encoding='utf-8')  # Явно указываем кодировку UTF-8
    logger.info("Configuration file successfully read")
except Exception as e:
    logger.error(f"Error reading configuration file: {e}")
    sys.exit(1)

# Telegram API data
try:
    api_id = int(config['Telegram']['api_id'])
    api_hash = config['Telegram']['api_hash']
    target_channel_id = int(config['Telegram']['target_channel_id'])
    logger.info(f"API data received. Target channel: {target_channel_id}")
except Exception as e:
    logger.error(f"Error getting API data: {e}")
    sys.exit(1)

# Source settings
try:
    source_channels = [int(channel.strip()) for channel in config['Sources']['source_channel_names'].split(',')]
    min_delay = float(config['Sources']['min_delay'])
    max_delay = float(config['Sources']['max_delay'])
    jitter_range = float(config['Sources']['jitter_range'])
    logger.info(f"Source settings received. Channels: {source_channels}")
    logger.info(f"Delay settings: min={min_delay}, max={max_delay}, jitter={jitter_range}")
except Exception as e:
    logger.error(f"Error getting source settings: {e}")
    sys.exit(1)

# Filter settings
try:
    stop_words = [word.strip() for word in config['Filters']['stop_words'].split(',')]
    skip_messages_with_links = config['Filters'].getboolean('skip_messages_with_links')
    logger.info(f"Filter settings received. Stop words: {stop_words}")
    logger.info(f"Skip messages with links: {skip_messages_with_links}")
except Exception as e:
    logger.error(f"Error getting filter settings: {e}")
    stop_words = []
    skip_messages_with_links = False
    logger.info("Using default filter settings")

# Client initialization
logger.info("Initializing Telegram client")
client = TelegramClient('forwarder_session', api_id, api_hash)

# Statistics counters
message_counter = 0
error_counter = 0
skipped_counter = 0
start_time = time.time()


async def check_for_links(message):
    """Check if message contains links"""
    if not message.text:
        return False

    # Check for link entities
    if message.entities:
        for entity in message.entities:
            if isinstance(entity, (MessageEntityUrl, MessageEntityTextUrl)):
                return True

    # Pattern for URLs
    url_pattern = re.compile(r'https?://\S+|www\.\S+')
    if url_pattern.search(message.text):
        return True

    return False


async def check_for_stop_words(message):
    """Check if message contains stop words"""
    if not message.text or not stop_words:
        return False

    message_text = message.text.lower()
    for word in stop_words:
        word_lower = word.lower()
        if word_lower in message_text:
            logger.info(f"Found stop word: {word}")
            return True

    return False


async def remove_links(message):
    logger.info("Starting message processing to remove links")

    link_count = 0
    if message.text:
        # Create a copy of the message text
        original_text = message.text
        new_text = original_text

        # If there are entities, process them in reverse order (to avoid shifting indices)
        if message.entities:
            link_entities = [entity for entity in message.entities
                             if isinstance(entity, (MessageEntityUrl, MessageEntityTextUrl))]

            link_count = len(link_entities)
            if link_count > 0:
                logger.info(f"Found {link_count} links in entities")

                # Sort entities in reverse order by position
                link_entities.sort(key=lambda e: e.offset, reverse=True)

                # Remove links from text
                for entity in link_entities:
                    start = entity.offset
                    end = start + entity.length
                    link_text = new_text[start:end]
                    logger.debug(f"Removing link at position {start}-{end}: {link_text}")
                    new_text = new_text[:start] + new_text[end:]

        # Additional check for URLs using regular expressions

        # Pattern for full URLs (http://, https://, www.)
        full_url_pattern = re.compile(r'https?://\S+|www\.\S+')

        # Pattern for detecting "https://" and "http://" without the rest of the URL
        partial_url_pattern = re.compile(r'https?://\s*')

        # Search and remove full URLs
        urls = full_url_pattern.findall(new_text)
        if urls:
            logger.info(f"Found {len(urls)} full URLs via regex")
            for url in urls:
                logger.debug(f"Removing URL: {url}")
            link_count += len(urls)
            new_text = full_url_pattern.sub('', new_text)

        # Search and remove URL prefixes (https://, http://)
        partial_urls = partial_url_pattern.findall(new_text)
        if partial_urls:
            logger.info(f"Found {len(partial_urls)} URL prefixes")
            for url in partial_urls:
                logger.debug(f"Removing URL prefix: {url}")
            link_count += len(partial_urls)
            new_text = partial_url_pattern.sub('', new_text)

        # Update message text
        if original_text != new_text:
            logger.info(f"Message text changed. Removed {link_count} links/prefixes")
            logger.debug(f"Original text: {original_text}")
            logger.debug(f"New text: {new_text}")
        else:
            logger.info("Message text unchanged (no links found)")

        message.text = new_text
        message.entities = None  # Remove all entities, since we changed the text
    else:
        logger.info("Message contains no text, only media")

    return message, link_count


# Add random delay for more natural behavior
async def random_delay():
    base_delay = random.uniform(min_delay, max_delay)
    jitter = random.uniform(-jitter_range, jitter_range)
    delay = base_delay + (base_delay * jitter)
    logger.info(f"Added random delay: {delay:.2f} seconds")
    await asyncio.sleep(delay)


# Handler for new messages in source channel
@client.on(events.NewMessage(chats=source_channels))
async def forward_handler(event):
    global message_counter, error_counter, skipped_counter

    try:
        source_channel_id = event.chat_id
        message_id = event.message.id
        logger.info(f"Received new message from channel {source_channel_id}, message ID: {message_id}")

        # Check for stop words
        has_stop_words = await check_for_stop_words(event.message)
        if has_stop_words:
            logger.info(f"Message contains stop words. Skipping.")
            skipped_counter += 1
            return

        # Check for links if we need to skip messages with links
        if skip_messages_with_links:
            has_links = await check_for_links(event.message)
            if has_links:
                logger.info(f"Message contains links. Skipping.")
                skipped_counter += 1
                return

        # Add random delay before forwarding
        await random_delay()

        # Get message
        message = event.message

        # Log media information
        has_media = message.media is not None
        media_type = type(message.media).__name__ if has_media else "None"
        logger.info(f"Media type in message: {media_type}")

        # Remove links
        message, removed_links = await remove_links(message)

        # If text is empty after link removal but there's media, just forward the media
        send_start_time = time.time()
        if (not message.text or message.text.strip() == '') and message.media:
            logger.info("Forwarding media only without text")
            await client.send_file(
                target_channel_id,
                message.media,
                caption=None
            )
        # Otherwise forward a normal message or message with media and text
        else:
            text_length = len(message.text) if message.text else 0
            logger.info(f"Forwarding message with text ({text_length} characters) {' and media' if has_media else ''}")
            await client.send_message(
                target_channel_id,
                message.text,
                file=message.media,
                formatting_entities=message.entities
            )

        send_time = time.time() - send_start_time
        message_counter += 1
        uptime = time.time() - start_time

        logger.info(f"Message successfully forwarded to channel {target_channel_id} in {send_time:.2f} seconds")
        logger.info(
            f"Statistics: processed {message_counter} messages, {error_counter} errors, skipped {skipped_counter} messages, uptime: {uptime / 60:.2f} minutes")

    except Exception as e:
        error_counter += 1
        logger.error(f"Error forwarding message: {e}", exc_info=True)


# Function to output statistics every hour
async def print_stats():
    while True:
        await asyncio.sleep(3600)  # Every hour
        uptime = time.time() - start_time
        success_rate = (message_counter / (message_counter + error_counter)) * 100 if (
                                                                                                  message_counter + error_counter) > 0 else 0

        logger.info("=" * 50)
        logger.info("STATISTICS")
        logger.info(f"Uptime: {uptime / 3600:.2f} hours")
        logger.info(f"Processed messages: {message_counter}")
        logger.info(f"Skipped messages: {skipped_counter}")
        logger.info(f"Errors: {error_counter}")
        logger.info(f"Success rate: {success_rate:.2f}%")
        logger.info("=" * 50)


# Bot startup
async def main():
    logger.info("=" * 50)
    logger.info("TELEGRAM MESSAGE FORWARDING BOT STARTUP")
    logger.info(f"Date and time of startup: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info(f"Monitored channels: {source_channels}")
    logger.info(f"Target channel: {target_channel_id}")
    logger.info(f"Stop words: {stop_words}")
    logger.info(f"Skip messages with links: {skip_messages_with_links}")
    logger.info("=" * 50)

    try:
        # Start client
        await client.start()
        logger.info("Telegram client successfully started and authenticated")

        # Start statistics task
        asyncio.create_task(print_stats())

        # Keep client active
        await client.run_until_disconnected()
    except Exception as e:
        logger.critical(f"Critical error: {e}", exc_info=True)
    finally:
        logger.info("Bot shutdown")


# Launch main function
if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Bot stopped by user (Ctrl+C)")
    except Exception as e:
        logger.critical(f"Unhandled exception: {e}", exc_info=True)