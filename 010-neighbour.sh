#!/bin/sh

### НАЧАЛО РАЗДЕЛА ДЛЯ РЕДАКТИРОВАНИЯ
### ЭТИ ДАННЫЕ НУЖНО ИЗМЕНИТЬ

# здесь нужно указать последние цифры кадастрового номера участка 
# где стоит оборудование, на котором запущен скрипт, например 
# kadastr_no="919"
kadastr_no="919"

# наименование провайдера
# нужно указать провайдера из списка (с появлением новых провайдеров список будет расширяться):
#   Дом.ру
#   iKorp
provider_name="Дом.ру"

# данные для подключения к серверу 
# mqtt_username и mqtt_password нужно взять у председателя
mqtt_username=000000
mqtt_password=PASSWORD

### КОНЕЦ РАЗДЕЛА ДЛЯ РЕДАКТИРОВАНИЯ
### ДАЛЬШЕ НИЧЕГО ТРОГАТЬ НЕ НУЖНО

# адрес сервера
mqtt_server="mqtt.sevsn.ru"

# порт
mqtt_port="1883"

# MQTT топик с результатом проверки доступности Яндекса
mqtt_topic="users/"$kadastr_no"/internet"

# команда отправляет три PING запроса к серверам Яндекса и Cloudflare
# и ждет ответа одну секунду
# если нет ответа в срок хотя бы на один запрос, завершается ошибкой
# успешное завершение выдает 10 цифр — время в формате UNIX 
# (количество секунд, прошедших с полуночи (00:00:00 UTC) 1 января 1970 года)
# неуспешное завершение выдает 0 — 1 января 1970 года
yandex_check_time=$(ping -c 3 -W 1 yandex.ru  > /dev/null; if [ $? -eq 0 ]; then echo $(date +%s); else echo "0"; fi)

cloudflare_check_time=$(ping -c 3 -W 1 1.1.1.1  > /dev/null; if [ $? -eq 0 ]; then echo $(date +%s); else echo "0"; fi)

# команда отправляет результаты предыдущих команд на
# MQTT сервер ТСН в топик users/НОМЕР_УЧАСТКА/internet
mosquitto_pub -d -t $mqtt_topic -m $provider_name -h $mqtt_server -p $mqtt_port -u $mqtt_username -P $mqtt_password
mosquitto_pub -d -t $mqtt_topic"/yandex" -m $yandex_check_time -h $mqtt_server -p $mqtt_port -u $mqtt_username -P $mqtt_password
mosquitto_pub -d -t $mqtt_topic"/cloudflare" -m $cloudflare_check_time -h $mqtt_server -p $mqtt_port -u $mqtt_username -P $mqtt_password
