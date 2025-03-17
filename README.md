# Telegram Forwarder Bot

Бот для автоматической пересылки сообщений из закрытых Telegram-каналов в ваш канал с фильтрацией ссылок. Поддерживает работу на Windows и Linux.

## 📝 Обзор проекта

Этот проект предоставляет Telegram юзер-бота для автоматической пересылки сообщений из закрытых каналов в ваш собственный канал. Бот пересылает сообщения в их исходном виде (текст, фото, видео, голосовые сообщения и другие медиа), удаляя все ссылки из текста.

### 🔑 Основные возможности:

- **Пересылка контента**: автоматическая пересылка сообщений из закрытых каналов в ваш канал
- **Фильтрация ссылок**: удаление всех URL, гиперссылок и префиксов ссылок (например, "https://") из пересылаемых сообщений
- **Поддержка медиа**: сохранение фото, видео, голосовых сообщений и других медиа-файлов
- **Естественное поведение**: случайные задержки между пересылками для маскировки автоматизации
- **Подробное логгирование**: отслеживание всех действий и ошибок
- **Статистика работы**: периодический вывод информации о работе бота
- **Запуск в фоновом режиме**: поддержка запуска как службы Windows или systemd на Linux

## 🛠️ Установка и настройка

### Предварительные требования

1. **Telegram API данные**:
   - Перейдите на [my.telegram.org](https://my.telegram.org) и войдите в свой аккаунт
   - Перейдите в раздел "API development tools"
   - Создайте новое приложение, указав любое название и краткое описание
   - Скопируйте `api_id` (числовое значение) и `api_hash` (строка символов)

2. **ID каналов**:
   - Для получения ID канала используйте бота [@username_to_id_bot](https://t.me/username_to_id_bot)
   - Перешлите сообщение из нужного канала этому боту
   - Он вернет ID канала (обычно отрицательное число, начинающееся с `-100`)

3. **Доступы**:
   - Вы должны быть участником исходного канала
   - Вы должны иметь права администратора в целевом канале

### Установка на Windows

1. Скачайте файл [setup_windows.bat](https://raw.githubusercontent.com/yourusername/telegram-forwarder/main/setup_windows.bat) и сохраните его на компьютере.

2. Запустите файл **от имени администратора** (щелкните правой кнопкой мыши → Запустить от имени администратора).

3. Скрипт автоматически:
   - Установит Python 3.12 (если он не установлен)
   - Создаст структуру проекта
   - Создаст конфигурационный файл
   - Установит все необходимые зависимости
   - Подготовит скрипты запуска

4. Отредактируйте файл `config.ini` в созданной папке `telegram-forwarder`, указав ваши данные.

5. Запустите бота с помощью файла `start_bot.bat`.

### Установка на Linux

1. Откройте терминал и скачайте скрипт установки:
   ```bash
   wget https://raw.githubusercontent.com/yourusername/telegram-forwarder/main/setup_linux.sh
   ```

2. Сделайте скрипт исполняемым:
   ```bash
   chmod +x setup_linux.sh
   ```

3. Запустите скрипт установки с правами sudo:
   ```bash
   sudo ./setup_linux.sh
   ```

4. Скрипт автоматически:
   - Установит Python 3.12
   - Создаст структуру проекта
   - Создаст конфигурационный файл
   - Установит все необходимые зависимости
   - Подготовит скрипты запуска и службу systemd

5. Отредактируйте файл `config.ini` в созданной папке `telegram-forwarder`, указав ваши данные.

6. Запустите бота с помощью:
   ```bash
   ./start_bot.sh
   ```

## ⚙️ Настройка параметров

Отредактируйте файл `config.ini` перед запуском:

```ini
[Telegram]
api_id = 12345678                  # Ваш API ID (числовое значение)
api_hash = abcdef1234567890abcdef  # Ваш API hash (строка)
target_channel_id = -1001234567890 # ID вашего целевого канала

[Sources]
source_channel_names = -1001987654321  # ID исходного канала или несколько через запятую
min_delay = 1                          # Минимальная задержка между пересылками (секунды)
max_delay = 2                          # Максимальная задержка (секунды)
jitter_range = 0.2                     # Случайная вариация задержки (коэффициент)
```

### Параметры задержки

- `min_delay` и `max_delay`: определяют диапазон задержки между пересылками сообщений (в секундах)
- `jitter_range`: добавляет случайную вариацию к задержке (рекомендуемое значение: 0.1-0.3)

**Рекомендация**: не устанавливайте слишком маленькие задержки (<1 секунды), чтобы избежать ограничений со стороны Telegram.

### Несколько исходных каналов

Вы можете добавить несколько исходных каналов, указав их через запятую:

```ini
source_channel_names = -1001234567890, -1001987654321, -1001112223334
```

## 🚀 Запуск бота

### Windows

1. **Обычный запуск**:
   - Запустите файл `start_bot.bat` в папке проекта

2. **Запуск как служба Windows** (для запуска в фоновом режиме):
   - Запустите файл `install_as_service.bat` от имени администратора
   - Это установит и запустит бота как службу Windows

### Linux

1. **Обычный запуск**:
   ```bash
   ./start_bot.sh
   ```

2. **Запуск как systemd служба** (для запуска в фоновом режиме):
   ```bash
   sudo ./install_service.sh
   ```

### Первый запуск

При первом запуске вам потребуется авторизоваться в Telegram:
1. Введите свой номер телефона (с кодом страны)
2. Введите полученный код подтверждения
3. При необходимости введите двухфакторный пароль

После успешной авторизации бот начнет отслеживать сообщения в указанных исходных каналах и пересылать их в ваш канал.

## 📊 Мониторинг и логи

### Логи

Бот создает подробные логи в директории `logs/` с именем файла, включающим текущую дату:

```
logs/forwarder_2025-03-17.log
```

### Просмотр логов

**Windows**:
- Откройте файл в любом текстовом редакторе
- Для логов службы: проверьте файл `logs/service.log`

**Linux**:
- Просмотр файла логов: `cat logs/forwarder_*.log`
- Просмотр последних 100 строк: `tail -n 100 logs/forwarder_*.log`
- Просмотр логов в реальном времени: `tail -f logs/forwarder_*.log`
- Для systemd службы: `sudo journalctl -u telegram-forwarder.service -f`

### Статистика

Каждый час бот автоматически выводит в логи статистику работы:
- Общее время работы
- Количество обработанных сообщений
- Количество ошибок
- Процент успешных операций

## 🔧 Управление ботом

### Windows

Если бот установлен как служба Windows:
1. Откройте "Управление компьютером" → "Службы и приложения" → "Службы"
2. Найдите службу "Telegram Forwarder Bot"
3. Используйте контекстное меню для запуска, остановки или перезагрузки службы

Или используйте команды:
```
sc start TelegramForwarder
sc stop TelegramForwarder
sc restart TelegramForwarder
```

### Linux

Если бот установлен как systemd служба:
```bash
# Проверка статуса
sudo systemctl status telegram-forwarder.service

# Запуск
sudo systemctl start telegram-forwarder.service

# Остановка
sudo systemctl stop telegram-forwarder.service

# Перезапуск
sudo systemctl restart telegram-forwarder.service

# Отключение автозапуска
sudo systemctl disable telegram-forwarder.service

# Включение автозапуска
sudo systemctl enable telegram-forwarder.service

# Просмотр логов
sudo journalctl -u telegram-forwarder.service

# Просмотр логов в реальном времени
sudo journalctl -u telegram-forwarder.service -f

# Просмотр последних 100 строк логов
sudo journalctl -u telegram-forwarder.service -n 100
```

## 🔍 Устранение неполадок

### Часто встречающиеся проблемы

1. **Ошибка авторизации**
   - Удалите файл `forwarder_session.session`
   - Запустите бота заново для повторной авторизации

2. **Бот не пересылает сообщения**
   - Проверьте, что вы являетесь участником исходного канала
   - Проверьте правильность ID каналов в config.ini
   - Проверьте логи на наличие ошибок доступа

3. **Ошибки при пересылке медиа**
   - Убедитесь, что у вас есть права на публикацию медиа в целевом канале
   - Проверьте, не превышен ли лимит на размер медиафайлов

4. **Бот внезапно останавливается**
   - Проверьте, не запустил ли Telegram защиту от флуда
   - Увеличьте значения параметров `min_delay` и `max_delay`
   - Проверьте логи на наличие ошибок

5. **Бот не запускается как служба**
   - **Windows**: Проверьте Windows Event Viewer для ошибок
   - **Linux**: Проверьте логи systemd: `sudo journalctl -u telegram-forwarder.service -b`

### Расширенное логгирование

Если вам нужны более подробные логи, вы можете изменить уровень логгирования в файле `forwarder.py`:

```python
logging.basicConfig(
    level=logging.DEBUG,  # Измените INFO на DEBUG для более подробных логов
    # остальные параметры...
)
```

## ⚠️ Предупреждения и ограничения

1. **Условия использования Telegram**: использование юзер-ботов может нарушать условия использования Telegram. Используйте на свой страх и риск.

2. **Ограничения API**: Telegram ограничивает количество запросов к API. Не устанавливайте слишком маленькие задержки между пересылками.

3. **Авторские права**: убедитесь, что пересылка контента не нарушает авторские права.

4. **Безопасность учетной записи**: не делитесь вашими `api_id` и `api_hash` с третьими лицами, чтобы избежать компрометации вашего аккаунта.

5. **Ограничения на количество пересылок**: Telegram может ограничивать количество пересылаемых сообщений в течение определенного периода.

## 🔄 Обновление и техническое обслуживание

### Обновление бота

1. Сохраните резервную копию вашего `config.ini` и `forwarder_session.session`
2. Загрузите последнюю версию скриптов
3. Замените файлы, сохранив конфигурацию и файл сессии
4. Установите возможные новые зависимости: `pip install -r requirements.txt`
5. Перезапустите бота

### Регулярное обслуживание

1. Периодически проверяйте логи на наличие ошибок
2. Очищайте старые файлы логов для экономии места
3. Проверяйте наличие обновлений Telethon и других зависимостей

### Очистка старых логов

**Windows** (batch файл для очистки логов старше 30 дней):
```batch
forfiles /p "logs" /m *.log /d -30 /c "cmd /c del @path"
```

**Linux** (bash скрипт для очистки логов старше 30 дней):
```bash
find logs/ -name "*.log" -type f -mtime +30 -delete
```

## 📋 Техническая информация

### Используемые технологии

- **Python 3.12**: основной язык программирования
- **Telethon**: библиотека для работы с Telegram API
- **asyncio**: асинхронное выполнение операций
- **re**: регулярные выражения для фильтрации ссылок
- **logging**: система логгирования
- **Windows NSSM** / **Linux systemd**: запуск в качестве службы

### Структура проекта

```
telegram-forwarder/
├── config.ini               # Конфигурационный файл
├── forwarder.py             # Основной скрипт бота
├── requirements.txt         # Список зависимостей
├── forwarder_session.session # Файл сессии Telegram (создается автоматически)
├── logs/                    # Директория с логами
│   └── forwarder_*.log      # Файлы логов
├── start_bot.bat/sh         # Скрипт запуска бота
├── install_as_service.bat   # Скрипт установки службы Windows
└── install_service.sh       # Скрипт установки службы Linux
```

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. Вы можете свободно использовать, изменять и распространять его в соответствии с условиями лицензии.

## 📱 Контакты и поддержка

Если у вас возникли проблемы или вопросы:
- Создайте issue в репозитории GitHub
- Проверьте логи на наличие ошибок
- Обратитесь к документации Telethon: https://docs.telethon.dev/

---

*Разработано с помощью Claude от Anthropic*