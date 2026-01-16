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

# Функция: определить провайдера по публичному IP
get_provider_by_ip() {
    # Получаем публичный IP (через внешний сервис)
    public_ip=$(curl -s https://api.ipify.org)
    if [ -z "$public_ip" ]; then
        echo "Не удалось определить IP адрес"
        return
    fi

    # Делаем whois-запрос и ищем организацию
    # (ВНИМАНИЕ!!! Требуется установить whois - opkg install whois)
    whois_data=$(whois "$public_ip" 2>/dev/null)
    
    # Проверяем ключевые слова
    case "$whois_data" in
        *Dom.ru*|*DOM.RU*|*ERTH*|*"Дом.ру"*)
            echo "Дом.ру"
            ;;
        *SCTS*|*IKORP*)
            echo "iKorp"        
            ;;
        *TELE2*|*tele2*)
            echo "TELE2"        
            ;;                    
        *Rostelecom*|*Ростелеком*)
            echo "Ростелеком"
            ;;
        *Megafon*|*Мегафон*)
            echo "Мегафон"
            ;;
        *MT_Russia*|*MTS*|*МТС*)
            echo "МТС"
            ;;
        *)
            # Если не нашли
            echo "Неизвестный провайдер"
            ;;
    esac
}

# Получаем название провайдера
provider_name=$(get_provider_by_ip)

# Проверяем доступность Яндекса
yandex_check_time=$(ping -c 3 -W 1 yandex.ru > /dev/null 2>&1; \
    if [ $? -eq 0 ]; then date +%s; else echo "0"; fi)

# Проверяем доступность Cloudflare
cloudflare_check_time=$(ping -c 3 -W 1 1.1.1.1 > /dev/null 2>&1; \
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
