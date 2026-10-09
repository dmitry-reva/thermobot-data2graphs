# Интеграция датчиков температуры Thermobot в Home Assistant (RestAPI)

*Использовать интеграцию для оригинальной прошивки не рекомендуется!* 
Решение через через REST API позволяет получать данные о температуре с устройств с оригинальной прошивкой от производителя.
Критика этого решения: смена ip-адресов датчиков, сложность интеграции. 

**Обновлено 04.10.2026**: Предлагается [заменить оригинальную прошивку от производителя на прошивку под ESPHome](esphome/README.MD) для использования в Home Assistant.

## Функциональность

Интеграция:
* два REST‑датчика для получения температуры с внешних устройств;
* MQTT‑датчик для публикации объединённых данных о температуре.

## Компоненты

### REST‑датчики

Два датчика, получающих данные по HTTP‑запросам с разных IP‑адресов:
* **Датчик 1**: `http://IP1/read`
* **Датчик 2**: `http://IP2/read`

**Особенности:**
* интервал опроса — 90 секунд;
* таймаут ответа — 20 секунд;
* обработка данных через регулярное выражение для извлечения числового значения температуры;
* класс устройства — температура (`device_class: temperature`).

### MQTT‑датчик

Публикует объединённые данные о температуре в топике MQTT:
* топик: `homeassistant/sensors/temperature`.

## Установка и настройка

### Шаг 1. Подготовка конфигурации Home Assistant

1. Откройте файл `configuration.yaml` вашего Home Assistant.
2. Добавьте в него приведённый ниже YAML‑код (раздел «Конфигурационный код»).

### Шаг 2. Замена IP‑адресов

Замените IP‑адреса в конфигурации на актуальные для ваших устройств:
* `IP1` — IP‑адрес первого устройства;
* `IP2` — IP‑адрес второго устройства.

### Шаг 3. Настройка MQTT

Убедитесь, что у вас настроен MQTT‑брокер:
1. Установите и настройте дополнение **MQTT Broker** (например, Mosquitto) в Home Assistant.
2. Проверьте подключение к брокеру.

### Шаг 4. Перезапуск Home Assistant

После внесения изменений:
1. Сохраните файл `configuration.yaml`.
2. Перезапустите Home Assistant через **«Настройки» → «Система» → «Перезапуск»**.

### Шаг 5. Проверка работы

1. Перейдите в **«Обзор»** и найдите датчики:
   * «Название датчика 1»;
   * «Название датчика 2».
2. Убедитесь, что датчики показывают корректные значения температуры.
3. Проверьте MQTT‑топик `homeassistant/sensors/temperature` на наличие данных.

## Конфигурационный код

```yaml
sensor:
  - platform: rest
    resource: http://IP1/read
    name: "Название датчика 1"
    unique_id: "temperatura_1"
    value_template: "{{ value | regex_findall('\\d+\\.\\d+') | first | float }}"
    unit_of_measurement: "°C"
    device_class: temperature
    scan_interval: 90
    force_update: true
    timeout: 20
    verify_ssl: false

  - platform: rest
    resource: http://IP2/read
    name: "Название датчика 2"
    unique_id: "temperatura_2"
    value_template: "{{ value | regex_findall('\\d+\\.\\d+') | first | float }}"
    unit_of_measurement: "°C"
    device_class: temperature
    scan_interval: 90
    force_update: true
    timeout: 20
    verify_ssl: false

mqtt:
  sensor:
    - name: "Температура датчиков для MQTT"
      state_topic: "homeassistant/sensors/temperature"
