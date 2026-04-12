#!/bin/bash

# Файл настроек

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
CONFIG_FILE=$SCRIPT_DIR"/settings.txt"

# Читаем MAC_LIST из файла
MAC_LIST=()
while IFS= read -r line || [[ -n "$line" ]]; do
    # Пропускаем пустые строки и комментарии
    [[ -z "$line" || "$line" =~ ^\s*# ]] && continue
    # Ищем строку с MAC_LIST
    if [[ "$line" =~ ^MAC_LIST=.* ]]; then
        # Извлекаем значение (убираем MAC_LIST= и пробелы)
        mac_str="${line#MAC_LIST=}"
        mac_str="${mac_str// /}"  # Убираем все пробелы
        IFS=',' read -ra macs <<< "$mac_str"
        MAC_LIST=("${macs[@]}")
    fi
done < "$CONFIG_FILE"

# Если MAC_LIST пуст — выходим
if [ ${#MAC_LIST[@]} -eq 0 ]; then
    echo "Ошибка: MAC_LIST не найден или пуст в $CONFIG_FILE"
    exit 1
fi

echo "Найденные MAC-адреса: ${MAC_LIST[*]}"

nmap -p 80 192.168.100.0/24

# Собираем список доступных IP
IP_LIST=()

for mac in "${MAC_LIST[@]}"; do
    echo "Обработка MAC: $mac"

    # Шаг 1: Находим IP по MAC (пример для Linux — через ARP)
    # Примечание: ARP-таблица может быть неполной; можно использовать nmap/arp-scan и т.п.
    ip=$(arp -n | grep -i "$mac" | awk '{print $1}')
    
    if [ -z "$ip" ]; then
        echo "IP для MAC $mac не найден в ARP-таблице"
        continue
    fi

    echo "Найден IP: $ip"

    # Шаг 2: Проверяем доступность по HTTP (HEAD-запрос)
    # Используем curl с таймаутом и проверкой кода ответа
    http_status=$(curl --head --silent --output /dev/null --write-out "%{http_code}" \
        --connect-timeout 5 --max-time 10 "http://$ip")

    if [ "$http_status" -ge 200 ] && [ "$http_status" -lt 400 ]; then
        echo "HTTP OK ($http_status) для $ip"
        IP_LIST+=("$ip")
    else
        echo "HTTP НЕДОСТУПЕН ($http_status) для $ip"
    fi
done

# Формируем строку IP_LIST
IP_LIST_STR=$(IFS=,; echo "${IP_LIST[*]}")

# Записываем IP_LIST в файл (заменяем существующую строку или добавляем)
if grep -q "^IP_LIST=" "$CONFIG_FILE"; then
    # Заменяем существующую строку
    sed -i "s/^IP_LIST=.*/IP_LIST=$IP_LIST_STR/" "$CONFIG_FILE"
else
    # Добавляем новую строку
    echo "IP_LIST=$IP_LIST_STR" >> "$CONFIG_FILE"
fi

echo "Список доступных IP записан в $CONFIG_FILE: $IP_LIST_STR"

