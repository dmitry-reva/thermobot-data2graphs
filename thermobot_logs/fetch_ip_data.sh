#!/bin/bash

# Параметры

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
CONFIG_FILE=$SCRIPT_DIR"/settings.txt"        # Файл с настройками
DATA_DIR="/var/log/thermobot_logs"              # Директория для логов (можно изменить)
REQUEST_TIMEOUT=10                # Таймаут запроса (сек)
DEFAULT_USER_AGENT="curl/7.x"    # User-Agent для запроса

# Создаём директорию для логов, если её нет
mkdir -p "$DATA_DIR"

# Проверяем существование файла настроек
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Ошибка: файл настроек '$CONFIG_FILE' не найден!" >&2
    exit 1
fi

# Читаем IP_LIST из файла
IP_LIST=()
while IFS= read -r line || [[ -n "$line" ]]; do
    # Пропускаем пустые строки и комментарии
    [[ -z "$line" || "$line" =~ ^\s*# ]] && continue
    # Ищем строку с IP_LIST
    if [[ "$line" =~ ^IP_LIST=.* ]]; then
        # Извлекаем значение (убираем IP_LIST= и пробелы)
        ip_str="${line#IP_LIST=}"
        ip_str="${ip_str// /}"  # Убираем все пробелы
        IFS=',' read -ra ips <<< "$ip_str"
        IP_LIST=("${ips[@]}")
    fi
done < "$CONFIG_FILE"

# Если IP_LIST пуст — выходим
if [ ${#IP_LIST[@]} -eq 0 ]; then
    echo "Ошибка: IP_LIST не найден или пуст в '$CONFIG_FILE'" >&2
    exit 1
fi

echo "Найденные IP-адреса: ${IP_LIST[*]}"

# Обрабатываем каждый IP
for ip in "${IP_LIST[@]}"; do
    # Формируем имя файла: ip_<IP>_data.log
    # Заменяем точки в IP на подчёркивания для корректного имени файла
    safe_ip=$(echo "$ip" | tr '.' '_')
    LOG_FILE="$DATA_DIR/ip_${safe_ip}_data.log"

    # Получаем текущую дату и время
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Выполняем HTTP GET-запрос к http://<IP>/read
    response=$(curl --silent --show-error \
        --connect-timeout "$REQUEST_TIMEOUT" \
        --max-time "$REQUEST_TIMEOUT" \
        --user-agent "$DEFAULT_USER_AGENT" \
        "http://$ip/read")

    # Открываем файл для дописывания
    {
     #   echo "[$timestamp] IP: $ip"
        if [ -n "$response" ]; then
            echo "$timestamp | $response"
        else
            echo "(Ошибка: не удалось получить ответ)"
        fi
        
    } >> "$LOG_FILE"

    echo "$timestamp данные для $ip записаны в $LOG_FILE"
done

# echo "Все запросы выполнены. Логи сохранены в директории '$DATA_DIR'."

