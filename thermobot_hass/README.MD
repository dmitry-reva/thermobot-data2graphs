# Thermobot → Home Assistant

Проект интеграции устройств **Thermobot‑2 Mini** (производитель — [42unita.ru](https://www.42unita.ru)) в **Home Assistant** для контроля температур в отопительных системах (подача и обратка).

Репозиторий содержит два независимых способа получить температуру в Home Assistant:

| | **ESPHome** ✅ рекомендуется | **REST API** ⚠️ legacy |
|---|---|---|
| Прошивка | замена заводской на ESPHome | оригинальная от производителя |
| Появление в HA | автоматически, через интеграцию ESPHome | вручную, по IP‑адресу |
| Получение данных | push (ESPHome API), 30 с | polling по HTTP, 90 с |
| Сущности | 2 температуры, калибровка, авария по порогам, LED, зуммер, кнопка, диагностика | 2 температуры (regexp по ответу) + MQTT‑датчик |
| Управление | HA + web‑интерфейс `heatflow.local`, OTA‑обновления | только правка `configuration.yaml` |
| Устойчивость | mDNS, стабильные `unique_id` | зависит от DHCP: смена IP ломает датчик |

> **Обновлено 04.10.2026.** Основной путь — [замена оригинальной прошивки на ESPHome](esphome/README.MD). Вариант с REST API оставлен для устройств, которые нельзя перепрошивать; подробности и критика подхода — в [RestAPI/README.md](RestAPI/README.md).

![Пример графика температуры в Home Assistant по данным ESPHome](esphome/images/hass-esphome-graf.png)

*Рисунок. График температур подачи и обратки в Home Assistant после перехода на ESPHome.*

---

## Содержание

- [Структура репозитория](#структура-репозитория)
- [Аппаратная часть](#аппаратная-часть)
- [Быстрый старт: ESPHome](#быстрый-старт-esphome)
- [Сущности в Home Assistant](#сущности-в-home-assistant)
- [Альтернатива: REST API](#альтернатива-rest-api)
- [Обновление прошивки](#обновление-прошивки)
- [Ограничения и важные замечания](#ограничения-и-важные-замечания)
- [Документация](#документация)

---

## Структура репозитория

```text
thermobot_hass/
├── README.MD                     # этот файл: обзор проекта
├── esphome/
│   ├── README.MD                 # подробная инструкция по ESPHome-прошивке
│   ├── heatflow.yaml             # основная прошивка (ESPHome 2026.9.1)
│   ├── thermobot.yaml            # реверс-инжиниринг заводской прошивки (справочно)
│   └── images/
│       ├── hass-esphome-graf.png # пример графика в HA
│       ├── PINOUT-MINI2.JPG      # схема пинов платы
│       └── write-bin.jpeg        # подключение USB-UART для прошивки
└── RestAPI/
    ├── README.md                 # инструкция по REST API-интеграции
    └── configuration.yaml        # фрагмент конфигурации Home Assistant
```

**Какой файл использовать:**

- `esphome/heatflow.yaml` — собирает `firmware.bin` для платы; это рабочая и поддерживаемая конфигурация.
- `esphome/thermobot.yaml` — справочный YAML, восстановленный из заводского дампа (повторяет GPIO и логику оригинала: TM1637, Telegram, таймер перезагрузки Wi‑Fi). Автором не тестировался — используйте как источник идей для миграции, а не как готовую прошивку.
- `RestAPI/configuration.yaml` — кусок `configuration.yaml` Home Assistant; его нужно объединить со своим файлом, а не заменять целиком.

---

## Аппаратная часть

- **Плата:** Thermobot‑2 Mini, модуль **ESP8266MOD** (4 МБ flash), производитель [42unita.ru](https://www.42unita.ru).
- **Датчики:** Dallas **DS18B20** (1‑Wire), в оригинале один, в проекте параллельно добавлен второй (подача/обратка). Адреса датчиков уникальны.
- **Индикация:** светодиод с инверсной логикой, пассивный зуммер.
- **Прошивка:** через адаптер **USB‑UART (CH340G)**, только 3,3 В.

| Сигнал | GPIO | Примечание |
|---|---|---|
| DS18B20 (1‑Wire data) | **GPIO0** | strapping‑пин: подтяжка 4,7 кОм к 3,3 В |
| Светодиод | **GPIO2** | инверсная логика; при загрузке должен быть HIGH |
| Зуммер (PWM) | **GPIO12** | в оригинале `tone(12, 3000, 100)` |
| Кнопка | **GPIO14** | `INPUT_PULLUP`, активный низкий уровень, опционально |
| TM1637 CLK / DIO | **GPIO4 / GPIO5** | только в `thermobot.yaml` (заводская прошивка) |

![Схема пинов Thermobot‑2 Mini](esphome/images/PINOUT-MINI2.JPG)

*Рисунок. Пины платы Thermobot‑2 Mini, используемые для прошивки.*

---

## Быстрый старт: ESPHome

Нужно: Home Assistant с интеграцией **ESPHome**, пакет **ESPHome** версии 2026.9.1 (на ней конфигурация проверена), адаптер USB‑UART, esptool.

### Шаг 1. Секреты

Создайте в каталоге `esphome/` файл `secrets.yaml`:

```yaml
wifi_0f: "ssid_вашей_сети_2.4GHz"       # в прошивке используется как wifi_ssid
wifi_password: "пароль_вашей_сети_2.4GHz"
web_server_pass: "пароль_для_веб_интерфейса"
api_key: "api_ключ_для_home_assistant"    # сгенерировать: esphome generate-encryption-key
```

### Шаг 2. Адреса DS18B20

В `esphome/heatflow.yaml` укажите реальные адреса датчиков. По умолчанию там стоят заведомо неверные значения:

```yaml
addr_supply: "0x00000000b34d1328"   # требует замены
addr_return: "0xb7000000cb2eb328"   # требует замены
```

Узнать адреса: соберите и прошейте прошивку с адресами `0x0000000000000000`, затем посмотрите логи устройства в ESPHome — в них будут перечислены найденные 1‑Wire устройства. После замены адресов прошейте ещё раз.

### Шаг 3. Сборка

```bash
esphome compile esphome/heatflow.yaml
```

На выходе — `firmware.bin` (`.esphome/build/heatflow/.pioenvs/heatflow/firmware.bin`).

### Шаг 4. Первая прошивка по USB‑UART

1. Подключите плату к адаптеру **по питанию 3,3 В** (не 5 В).
2. Войдите в режим загрузчика: при подключении платы замкните GND→GPIO0, затем GND→RST, отпустите RST, отпустите GPIO0.
3. Прошейте (замените `COM4` и путь к `firmware.bin`):

```powershell
esptool --chip esp8266 --port COM4 --baud 115200 write-flash --flash-mode qio --flash-size 4MB 0x00000 firmware.bin
```

Успешный вывод заканчивается строками `Hash of data verified.` и `Hard resetting via RTS pin...`.

> **Важно.** USB Type‑C на плате для прошивки **не используется** — только для питания уже прошитого устройства. Подробности, фото подключения и разбор ошибок — в [esphome/README.MD](esphome/README.MD).

### Шаг 5. Подключение к Home Assistant

После загрузки устройство поднимает Wi‑Fi (при неудаче — точка доступа `<friendly_name>` с паролем из `web_server_pass` и captive portal) и становится доступно:

- в локальной сети по mDNS: [heatflow.local](http://heatflow.local), плюс web‑интерфейс на порту 80;
- в Home Assistant — автоматически, через интеграцию **ESPHome** (API‑шифрование по `api_key`). Если автообнаружение не сработало: «Настройки» → «Устройства и службы» → «Добавить интеграцию» → **ESPHome** → хост `heatflow.local`, порт `6053`, ключ шифрования из `secrets.yaml`.

---

## Сущности в Home Assistant

Имена могут отличаться, если вы изменили `friendly_name` / `devicename`.

| Платформа | Сущность | Назначение |
|---|---|---|
| sensor | **Supply temperature** | температура подачи, °C (калибровка складывается с показанием) |
| sensor | **Return temperature** | температура обратки, °C |
| sensor | **HeatFlow WiFi Signal** | уровень Wi‑Fi, дБ |
| sensor | **HeatFlow Uptime Sensor** | время работы, с |
| binary_sensor | **Temperature alarm** | `problem` = любой датчик вне порогов; при срабатывании — мигание и повторяющийся звук |
| binary_sensor | **Button** | кнопка на GPIO14 (опционально) |
| number | **Supply calibration**, **Return calibration** | ручная калибровка, −10…+10 °C, шаг 0,1 |
| number | **Alarm low temperature**, **Alarm high temperature** | пороги аварии (по умолчанию 5 и 90 °C) |
| number | **Alarm repeat interval** | период повторения сигнала аварии, с (по умолчанию 60) |
| number | **Sound volume**, **Sound frequency**, **Sound duration** | настройка зуммера: 0–100 %, 500–5000 Гц, 20–2000 мс |
| switch | **Led** | светодиод индикации |
| switch | **Sound** | общий выключатель звука (boot/connect/alarm) |
| button | **Beep test** | тестовый сигнал в обход выключателя «Sound» |

Параметры калибровки, порогов и звука сохраняются в flash (`restore_value: true`) и переживают перезагрузку. Значения, помеченные в YAML как «new in this revision», стоит проверить при первой сборке.

---

## Альтернатива: REST API

Для устройств с **заводской** прошивкой: Home Assistant опрашивает `http://IP/read` двух датчиков и извлекает число регулярным выражением. Конфигурация — [RestAPI/configuration.yaml](RestAPI/configuration.yaml), инструкция — [RestAPI/README.md](RestAPI/README.md).

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

mqtt:
  sensor:
    - name: "Температура датчиков для MQTT"
      state_topic: "homeassistant/sensors/temperature"
```

Что нужно учесть:

- `IP1` / `IP2` — статические адреса устройств; при смене IP датчик перестаёт обновляться.
- MQTT‑сущность только **подписана** на топик `homeassistant/sensors/temperature` — публиковать значения должен отдельный издатель (автоматизация/скрипт), и для неё нужен настроенный MQTT‑брокер (например, Mosquitto).
- После правки `configuration.yaml` — «Настройки» → «Система» → «Перезапуск», затем проверка датчиков в «Обзоре».
- Подход не рекомендован: смена IP и ручная правка YAML. Предпочтительна [ESPHome‑прошивка](esphome/README.MD).

---

## Обновление прошивки

После первой прошивки по USB дальнейшие обновления — по воздуху:

- **ESPHome Dashboard / CLI:** `esphome run esphome/heatflow.yaml` (OTA);
- **web‑интерфейс устройства:** [heatflow.local](http://heatflow.local), раздел OTA;
- **Home Assistant:** карточка устройства → «Обновить» (ESPHome integration).

---

## Ограничения и важные замечания

- **Заводские адреса DS18B20 нужно заменить** — иначе температуры не будет (см. шаг 2).
- **GPIO0 и GPIO2 — strapping‑пины.** Датчик не должен тянуть линию к земле при старте, а GPIO2 при загрузке должен быть HIGH; подтяжка 4,7 кОм к 3,3 В обязательна.
- **Питание только 3,3 В** при прошивке через USB‑UART; Type‑C — лишь питание.
- **Калибровка** — смещение, прибавляемое к «сырому» показанию: `value = raw + calibration`. Применяется со следующего измерения (интервал 30 с). В `heatflow.yaml` для подачи по умолчанию стоит смещение 3,5 °C — унаследовано от старого жёстко заданного фильтра.
- **Авария не срабатывает на отсутствующий датчик:** `NaN`/нет состояния трактуются как «в норме», сигнализируется только выход за пороги.
- **`thermobot.yaml`** содержит Telegram‑уведомления и таймер перезагрузки Wi‑Fi из заводской прошивки — требует своих секретов `tg_token`, `tg_chat`, `ota_password`, `wifi_ssid` и не проверялся на железе.

---

## Документация

- [esphome/README.MD](esphome/README.MD) — назначение устройства, функции, аппаратная часть, прошивка esptool, настройка секретов, развитие проекта.
- [RestAPI/README.md](RestAPI/README.md) — REST/MQTT‑интеграция, установка и проверка.
- [esphome/heatflow.yaml](esphome/heatflow.yaml) — рабочая конфигурация ESPHome.
- [esphome/thermobot.yaml](esphome/thermobot.yaml) — восстановленный конфиг заводской прошивки.
- [RestAPI/configuration.yaml](RestAPI/configuration.yaml) — фрагмент `configuration.yaml` для Home Assistant.
