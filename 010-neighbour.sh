#!/bin/sh

### НАЧАЛО РАЗДЕЛА ДЛЯ РЕДАКТИРОВАНИЯ
### ЭТИ ДАННЫЕ НУЖНО ИЗМЕНИТЬ

# здесь нужно указать последние цифры кадастрового номера участка 
# где стоит оборудование, на котором запущен скрипт, например 
# kadastr_no="919"
kadastr_no="919"

# данные для подключения к серверу 
# mqtt_username и mqtt_password нужно взять у председателя
mqtt_username=000000
mqtt_password=password

### КОНЕЦ РАЗДЕЛА ДЛЯ РЕДАКТИРОВАНИЯ
### ДАЛЬШЕ НИЧЕГО ТРОГАТЬ НЕ НУЖНО

# Настройки сервера
mqtt_server="mqtt.sevsn.ru"
mqtt_port="1883"
mqtt_topic="users/$kadastr_no/internet_state"

# Путь к кешу
CACHE_FILE="/tmp/provider_cache.txt"

# Функция: получить кешированные данные
get_cached_provider() {
    if [ -f "$CACHE_FILE" ]; then
        . "$CACHE_FILE"  # Загружаем переменные из файла
        echo "$cached_provider"
    else
        echo ""
    fi
}

# Функция: сохранить в кеш
save_to_cache() {
    local ip="$1"
    local provider="$2"
    echo "cached_ip='$ip'" > "$CACHE_FILE"
    echo "cached_provider='$provider'" >> "$CACHE_FILE"
}

# Функция: определить провайдера по публичному IP (с кешированием)
get_provider_by_ip() {
    # Получаем текущий публичный IP
    public_ip=$(curl -s https://api.ipify.org)
    if [ -z "$public_ip" ]; then
        echo "Не удалось определить IP адрес"
        return
    fi

    # Проверяем кеш: если IP не изменился, возвращаем кешированный провайдер
    cached_provider=$(get_cached_provider)
    if [ -n "$cached_provider" ]; then
        . "$CACHE_FILE"  # Перезагружаем переменные
        if [ "$cached_ip" = "$public_ip" ]; then
            echo "$cached_provider"
            return
        fi
    fi

    # Если IP изменился или кеша нет — делаем whois
    whois_data=$(whois "$public_ip" 2>/dev/null)

    # Определяем провайдера
    case "$whois_data" in
        *Dom.ru*|*DOM.RU*|*ERTH*|*"Дом.ру"*)
            provider="Дом.ру"
            ;;
        *SCTS*|*IKORP*)
            provider="iKorp"
            ;;
        *TELE2*|*tele2*)
            provider="TELE2"
            ;;
        *Rostelecom*|*Ростелеком*)
            provider="Ростелеком"
            ;;
        *Megafon*|*Мегафон*)
            provider="Мегафон"
            ;;
        *MT_Russia*|*MTS*|*МТС*)
            provider="МТС"
            ;;
        *)
            provider="Неизвестный провайдер"
            ;;
    esac

    # Сохраняем в кеш
    save_to_cache "$public_ip" "$provider"
    echo "$provider"
}

# Получаем название провайдера (с использованием кеша)
provider_name=$(get_provider_by_ip)

# Проверяем доступность Яндекса
yandex_check_time=$(ping -c 2 -W 1 yandex.ru > /dev/null 2>&1; \
    if [ $? -eq 0 ]; then date +%s; else echo "0"; fi)

# Проверяем доступность Cloudflare
cloudflare_check_time=$(ping -c 2 -W 1 1.1.1.1 > /dev/null 2>&1; \
    if [ $? -eq 0 ]; then date +%s; else echo "0"; fi)

# Формируем JSON
json_payload="{\"provider\": \"$provider_name\",
    \"yandex_check_time\": $yandex_check_time,
    \"cloudflare_check_time\": $cloudflare_check_time}"

# Публикуем JSON в MQTT
mosquitto_pub -d \
    -t "$mqtt_topic" \
    -m "$json_payload" \
    -h "$mqtt_server" \
    -p "$mqtt_port" \
    -u "$mqtt_username" \
    -P "$mqtt_password"
