# Различия `thermobot-cc.yaml` и `thermobot-ds.yaml`

Сравнение двух ESPHome-конфигураций Thermobot по состоянию на 24.10.2026.
Проверка выполнялась на **ESPHome 2026.10.0**.

- [`thermobot-cc.yaml`](thermobot-cc.yaml) — справочная реконструкция заводской прошивки, 222 строки.
  По README на железе не тестировалась.
- [`thermobot-ds.yaml`](thermobot-ds.yaml) — реконструкция, собранная по анализу
  дампа `assets/thermobot-mini/dump13.bin`, 674 строки. Проходит `esphome config`,
  сгенерированный C++ компилируется.

Обе конфигурации описывают одно и то же устройство (ESP8266 + DS18B20 + LED + зуммер +
TM1637 + Telegram), используют одинаковые GPIO и во многом повторяют друг друга.
Ниже — все содержательные различия.

---

## Краткая сводка

| Параметр | `thermobot-cc.yaml` | `thermobot-ds.yaml` |
|---|---|---|
| Плата | `esp12e` | `nodemcuv2` |
| Версия ESPHome | не задана (рассчитана на 2026.9.x) | `min_version: 2026.10.0` |
| Запуск: звук/мигание при старте | нет | да (`on_boot`, priority −100) |
| Сигнал при подключении к Wi-Fi | нет | да (писк + 4 мигания) |
| Wi-Fi SSID (секрет) | `wifi_ssid` | `wifi_0f` |
| Канал точки доступа | не задан | `channel: 1` (substitution) |
| Web-сервер | порт 80, без авторизации | порт 80, digest-auth, `local: true`, `log: false` |
| Логгер | по умолчанию (DEBUG, 115200) | WARN, serial выключен |
| API: `reboot_timeout` | по умолчанию 15 мин | `0s` |
| OTA | с паролем (`ota_password`) | без пароля (ключ шифрования API) |
| `safe_mode` | нет | да |
| Период опроса DS18B20 | 5 с | 10 с |
| Десятичных знаков температуры | 1 | 2 |
| Пороги по умолчанию | 5 / 30 °C | −55 / 125 °C (оповещение выключено) |
| Интервал оповещения | 600 с | 600 с |
| Калибровка | 0 °C | 0 °C |
| Перезагрузка Wi-Fi | 0 мин | 0 мин |
| Авария как сущность HA | нет (логика в `on_value`) | `binary_sensor` «Temperature alarm» |
| Отказ датчика как сущность | нет (`on_error`, не работает в 2026.10) | `binary_sensor` «Temperature sensor fault» |
| Мигание LED при аварии | нет | да |
| Подтверждение сигнала | нет | кнопка + физическая кнопка |
| Telegram-сообщение | фиксированный английский текст | настраиваемый шаблон с `{t}`, `{lo}`, `{hi}` |
| URL-кодирование текста | нет (только ASCII) | да (кириллица, пробелы, знаки) |
| Wi-Fi restart | полная перезагрузка (`App.safe_reboot`) | `wifi.disable` + 3 с + `wifi.enable` |
| Диагностика (WiFi, uptime, IP/SSID/BSSID) | нет | да |
| Кнопки Restart / Safe mode | нет | да |
| Проверка `esphome config` (2026.10) | не проходит без правок (см. §16) | проходит |

---

## 1. Назначение, оформление и метаданные

| | `thermobot-cc.yaml` | `thermobot-ds.yaml` |
|---|---|---|
| Заголовок | 3 строки комментариев | большой блок: что найдено в дампе, что воспроизведено, отличия, таблица соответствия настройкам, примечания |
| `esphome.comment` | нет | есть |
| `esphome.project` | нет | `deepseek.thermobot_factory_clone`, версия `1.0.0` |
| `min_version` | нет | `2026.10.0` |
| `name_add_mac_suffix` | не задан (по умолчанию `false`) | `false` явно |
| `on_boot` | нет | писк + мигание |
| Имена подстановок | `name`, `pin_ds18b20` | `devicename`, `friendly_name`, `pin_onewire` + блоки `ap_*`, `buzzer_*`, `*_default` |
| Секреты в `substitutions` | только `tg_token`, `tg_chat` | все: Wi-Fi, web, API, Telegram |

У `thermobot-ds.yaml` в `substitutions` вынесены значения по умолчанию
(пороги, интервал, калибровка, таймер Wi-Fi) и параметры точки доступа/зуммера —
их можно менять в одном месте. В `thermobot-cc.yaml` числа и тексты зашиты
непосредственно в сущности.

## 2. Плата, API, OTA, safe mode

- **Плата:** `esp12e` против `nodemcuv2`. Обе — ESP8266 с 4 МБ flash; различие в
  выборе board-профиля и комментариях (в `thermobot-cc.yaml` упомянут GD25Q32C и
  вариант `esp01_1m` для 1 МБ).
- **API:** в `thermobot-cc.yaml` `reboot_timeout` не задан → действует штатный
  таймаут 15 минут.
  В `thermobot-ds.yaml` — `0s`, чтобы устройство не перезагружалось при
  недоступном Home Assistant.
- **OTA:** `thermobot-cc.yaml` использует legacy-пароль `ota_password`; в
  `thermobot-ds.yaml` пароля нет — OTA идёт через ключ шифрования API
  (`platform: esphome`).
- **safe mode:** только в `thermobot-ds.yaml`.
- `restore_from_flash: true` — в обоих.

## 3. Wi-Fi и точка доступа

| | `thermobot-cc.yaml` | `thermobot-ds.yaml` |
|---|---|---|
| Клиент Wi-Fi | `!secret wifi_ssid` / `wifi_password` | `!secret wifi_0f` / `wifi_password` |
| AP SSID / пароль | `THERMOBOT` / `88888888` | то же, но через `substitutions` |
| Канал AP | не задан (значение ESPHome по умолчанию) | `channel: 1` |
| `on_connect` | нет | писк + 4 мигания |
| `captive_portal` | да | да |

Из-за разных имён секретов `thermobot-cc.yaml` требует `wifi_ssid`, а
`thermobot-ds.yaml` — `wifi_0f`. В `secrets.example.yaml` сейчас есть
`wifi_0f`, `wifi_password`, `web_server_pass`, `api_key`, `tg_token`, `tg_chat` —
этого достаточно для `thermobot-ds.yaml`; для `thermobot-cc.yaml` нужны ещё
`wifi_ssid` и `ota_password`.

## 4. Web-сервер и логирование

- Оба используют `web_server` на порту 80. В ESPHome 2026.10 по умолчанию
  `version: 2`, поэтому фактически обе конфигурации отдают v2-интерфейс.
- `thermobot-cc.yaml`: без `local`, без авторизации, с логом.
- `thermobot-ds.yaml`: `local: true`, `log: false`, digest-авторизация
  (`web_server_user` = `thermobot`, пароль `web_server_pass`), то есть вкладка
  логов закрыта, а сам UI — только для локальной сети.
- **Логгер:** `thermobot-cc.yaml` оставляет значения по умолчанию (DEBUG, serial
  115200), `thermobot-ds.yaml` — `WARN` и `baud_rate: 0` (тихий режим, как
  в рабочей прошивке).

## 5. 1-Wire и датчик DS18B20

| | `thermobot-cc.yaml` | `thermobot-ds.yaml` |
|---|---|---|
| `one_wire` | без `id` | `id: bus_1wire` |
| `one_wire_id` у `dallas_temp` | не указан | `bus_1wire` |
| Имя сущности | `Температура` | `Temperature` |
| `update_interval` | `5s` | `10s` (substitution `temp_update_interval`) |
| `accuracy_decimals` | 1 | 2 |
| `filters` калибровки | `x + id(calib).state` | `x + id(calibration).state` с проверкой `isnan` |
| `on_value` | да — вся логика аварии | нет |
| `on_error` | да — `logger.log` (не работает в 2026.10) | нет |

В `thermobot-ds.yaml` калибровка защищена от `NaN`: если значение
настройки ещё не пришло, возвращается сырое `x`, а не `NaN`.
В `thermobot-cc.yaml` такой защиты нет.

## 6. Калибровка

| | `thermobot-cc.yaml` | `thermobot-ds.yaml` |
|---|---|---|
| ID | `calib` | `calibration` |
| Диапазон | −5…+5 °C, шаг 0.1 | −5…+5 °C, шаг 0.1 |
| Значение по умолчанию | 0 | 0 |
| `restore_value` | да | да |
| `mode`, `entity_category`, `icon` | нет | `box`, `config`, `mdi:thermometer-plus` |

## 7. Пороги и аварийная логика

### Значения по умолчанию

- `thermobot-cc.yaml`: **5 / 30 °C**.
- `thermobot-ds.yaml`: **−55 / 125 °C** — весь допустимый диапазон, то есть
  оповещения выключены, пока пользователь не задаст пороги. Это соответствует
  найденной в дампе строке «не введен» для незаданных границ. Вариант 5/30
  включается заменой `alarm_low_default` / `alarm_high_default`.

### Реализация

`thermobot-cc.yaml`:

- логика живёт в `on_value` датчика;
- глобальная переменная `last_alert_ms` хранит время последнего сообщения;
- первое срабатывание — сразу при выходе за границы;
- повтор — только когда пришло новое измерение и прошёл `notify_interval`;
- при возврате в норму `last_alert_ms` сбрасывается;
- пороговое состояние **не публикуется** в Home Assistant;
- нет мигания LED, нет подтверждения, нет отдельной сущности отказа датчика
  (`on_error` пишет только в лог и в 2026.10 не поддерживается).

`thermobot-ds.yaml`:

- отдельный `binary_sensor` «Temperature alarm» (`device_class: problem`,
  `trigger_on_initial_state: true`, `delayed_on: 5s`, `delayed_off: 30s`) —
  состояние видно в HA и в истории;
- скрипт `alarm_loop` в цикле мигает LED, пищит и отправляет Telegram каждые
  `alarm_interval` секунд, пока авария активна;
- `on_release` вызывает `stop_alarm` (светодиод и зуммер выключаются);
- отдельный `binary_sensor` «Temperature sensor fault» (`delayed_on: 90s`)
  ловит `NaN` и отправляет сообщение «нет датчика»;
- подтверждение кнопкой «Acknowledge alarm» и коротким нажатием физической
  кнопки останавливает локальный сигнал, не снимая аварию;
- в аварии участвует только валидная температура: `NaN` аварию не вызывает.

## 8. Telegram

| | `thermobot-cc.yaml` | `thermobot-ds.yaml` |
|---|---|---|
| Скрипт | `send_alert` (`mode: queued`, параметр `t: float`) | `send_telegram` (`mode: single`, параметр `message: std::string`) |
| Текст | жёстко зашит: `Thermobot temperature %.1f C out of range` | шаблон в сущности `text` «Telegram message»: `Термометр: температура {t} °C вне границ {lo}…{hi} °C` |
| Подстановка значений | `snprintf` в буфер `char[256]` | замена `{t}`, `{lo}`, `{hi}` в `std::string` |
| URL-кодирование | нет; пробелы закодированы вручную (`%20`), текст только ASCII | да, побайтовое: кириллица, пробелы, `%`, `&` и т. п. |
| Буфер | 256 байт, длинный текст обрежется | без фиксированного буфера |
| Сообщение при отказе датчика | нет (только лог) | да, «нет датчика» |
| `verify_ssl` | внутри действия `http_request.get` (в 2026.10 недопустимо) | на верхнем уровне `http_request:` |
| `follow_redirects` | по умолчанию | `true` явно |
| `timeout` / `useragent` | `10s` / `esphome-thermobot` | то же |

Обе конфигурации **только отправляют** сообщения: приёма команд бота
(`getUpdates`) нет ни в одной. В `thermobot-ds.yaml` это заявлено явно,
команды заменены сущностями HA.

## 9. Звук и светодиод

`thermobot-cc.yaml`:

- зуммер через компонент `rtttl`, нота `f#` в 7-й октаве (~2960 Гц, 100 мс) —
  приближение к заводскому `tone(12, 3000, 100)`;
- выключатель «Звуковой сигнал» только запрещает новые сигналы, уже звучащий тон
  не останавливает;
- LED — сущность «Led», без категории;
- кнопки «Beep test» нет;
- при старте и подключении к Wi-Fi устройство молчит.

`thermobot-ds.yaml`:

- зуммер через `esp8266_pwm` и скрипт `buzzer_tone`: 3000 Гц, скважность 50 %,
  100 мс (`buzzer_frequency`, `buzzer_duration`);
- выключатель «Sound» при выключении останавливает уже звучащий тон и сбрасывает
  скважность в 0 %;
- LED — сущность «LED», `entity_category: config`;
- есть кнопка «Beep test» (игнорирует выключатель Sound);
- при загрузке — писк и мигание, при подключении к Wi-Fi — писк и 4 мигания.

## 10. Кнопки и подтверждение

| | `thermobot-cc.yaml` | `thermobot-ds.yaml` |
|---|---|---|
| Физическая кнопка | `binary_sensor` «Кнопка», без действий | «Physical button»: скрыта по умолчанию, `on_click` сбрасывает сигнал |
| «Beep test» | нет | да |
| «Acknowledge alarm» | нет | да |
| «Restart» | нет | да |
| «Safe mode» | нет | да |

## 11. Дисплей TM1637

Совпадают: пины `GPIO4`/`GPIO5`, `intensity: 5`, `update_interval: 1s`,
показ `----` при отсутствии датчика.

Различия в лямбде:

- `thermobot-cc.yaml`: `if (id(temp).has_state()) it.printf("%.1f", ...)`.
  Для значений вне −9.9…99.9 строка получается длиннее 4 символов
  (например, `-10.5`), и пятый символ не помещается в индикатор
  (теряется дробная часть).
- `thermobot-ds.yaml`: `std::isnan`, для обычного диапазона `%4.1f`
  (ровно 4 знакоместа), для `≤ −10` и `≥ 100` — `%.0f`, то есть целое число.

## 12. Настройки (number) и текст

| | `thermobot-cc.yaml` | `thermobot-ds.yaml` |
|---|---|---|
| Количество `number` | 5 | 5 |
| Имена | русские («Нижняя граница», «Верхняя граница», «Интервал оповещения», «Калибровка», «Перезагрузка Wi-Fi (мин, 0=выкл)») | английские (`Alarm low`, `Alarm high`, `Alarm repeat interval`, `Calibration`, `Wi-Fi restart interval`) |
| Единицы | °C и s; у таймера Wi-Fi единицы нет | °C, s, min; `device_class` у границ и интервала |
| `mode: box` | нет | да |
| `entity_category: config` | нет | да |
| Иконки | нет | да |
| Значения по умолчанию | вписаны в сущности | вынесены в `substitutions` |
| `text`-сущность | нет | «Telegram message» (шаблон сообщения) |

Диапазоны у всех настроек совпадают: −55…125 °C, 1…86400 с, −5…+5 °C, 0…1440 мин.

## 13. Диагностика

В `thermobot-cc.yaml` нет ни `wifi_signal`, ни `uptime`, ни `text_sensor` с IP/SSID/BSSID,
ни `binary_sensor` статуса, ни версии ESPHome.

В `thermobot-ds.yaml` добавлены:

- `sensor.wifi_signal` (60 с);
- `sensor.uptime` (300 с);
- `binary_sensor.status`;
- `text_sensor` IP Address, SSID, BSSID;
- `text_sensor` ESPHome Version (скрыт по умолчанию).

## 14. Таймер перезагрузки Wi-Fi

| | `thermobot-cc.yaml` | `thermobot-ds.yaml` |
|---|---|---|
| Тик | 60 с | 60 с |
| Счётчик | `static uint32_t` внутри лямбды | глобальная `wifi_minutes` |
| Действие | `App.safe_reboot()` — **полная перезагрузка устройства** | `wifi_module_restart`: `wifi.disable` → 3 с → `wifi.enable` — **перезапуск только Wi-Fi** |
| Сброс счётчика | после перезагрузки (естественно) | явный сброс в 0 |
| Логирование | нет | `logger.log` |
| 0 = выкл | да | да |

Формально заводская настройка называется «перезагрузка Wi-Fi модуля», поэтому
вариант `wifi.disable/enable` ближе к оригиналу; `App.safe_reboot()` перезагружает
устройство целиком.

## 15. Секреты

| Секрет | `thermobot-cc.yaml` | `thermobot-ds.yaml` |
|---|---|---|
| `wifi_ssid` | да | — |
| `wifi_0f` | — | да |
| `wifi_password` | да | да |
| `api_key` | да | да |
| `ota_password` | да | — |
| `web_server_pass` | — | да |
| `tg_token` | да | да |
| `tg_chat` | да | да |

## 16. Совместимость и проверка

- **`thermobot-cc.yaml` на ESPHome 2026.10.0 не проходит `esphome config`**:
  1) `on_error` не является допустимой опцией `sensor.dallas_temp`;
  2) после удаления `on_error` — `verify_ssl` внутри `http_request.get`
     недопустим, опция перенесена на верхний уровень компонента `http_request`.
  После этих двух правок конфигурация становится валидной (проверено).
  На ESPHome 2026.9.x, под который она писалась, ошибок, вероятно, нет.
- **`thermobot-ds.yaml`** проходит `esphome config` на 2026.10.0;
  сгенерированный C++ (включая лямбды) успешно компилируется xtensa-тулчейном.
  Полная линковка в среде проверки не выполнялась.
- README прямо указывает, что `thermobot-cc.yaml` на железе не тестировался;
  `thermobot-ds.yaml` — тоже новая конфигурация, требующая проверки на
  реальной плате.

## 17. Что есть только в одном файле

**Только в `thermobot-cc.yaml`:**

- компонент `rtttl` (мелодия вместо ручного PWM);
- `on_value`-логика аварии и глобальная `last_alert_ms`;
- `on_error` у датчика (нерабочий в 2026.10);
- OTA-пароль;
- `board: esp12e`.

**Только в `thermobot-ds.yaml`:**

- `on_boot` и `on_connect` со звуком/миганием;
- `safe_mode`, project-метаданные, `min_version`;
- авторизация web-сервера и `local: true`;
- `text`-сущность с шаблоном Telegram-сообщения;
- авария и отказ датчика как отдельные `binary_sensor`;
- подтверждение сигнала (кнопка и физическая кнопка);
- кнопки Beep test / Restart / Safe mode;
- диагностические сенсоры и `status`;
- `wifi.disable/enable` вместо полной перезагрузки;
- URL-кодирование Telegram-сообщения.

## 18. Итог

- `thermobot-cc.yaml` — компактный «минимальный» вариант: датчик, пороги,
  Telegram, зуммер и дисплей, без лишних сущностей. Ближе к черновику и
  требует правок для ESPHome 2026.10.
- `thermobot-ds.yaml` — более полная реконструкция заводского поведения:
  все настройки как сущности HA, авария и отказ датчика видны в Home Assistant,
  есть подтверждение сигнала, диагностика и защита от `NaN`, сообщение
  настраивается без перепрошивки. Плата — та же, GPIO совпадают, поэтому
  конфигурации взаимозаменяемы (но entity_id и имена сущностей различаются).
