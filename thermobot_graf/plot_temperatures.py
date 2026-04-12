#!/usr/bin/env python3

import os
import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from datetime import datetime
import glob

# Параметры
LOG_DIR = "/var/log/thermobot_logs/"
OUTPUT_DIR = "/opt/thermobot_graf"
OUTPUT_HTML = os.path.join(OUTPUT_DIR,"temperature_dashboard.html")
FILE_PATTERN = os.path.join(LOG_DIR, "*.log")

# Список файлов для обработки
csv_files = glob.glob(FILE_PATTERN)

if not csv_files:
    print(f"Ошибка: файлы по шаблону {FILE_PATTERN} не найдены!")
    exit(1)

print(f"Найдено файлов: {len(csv_files)}")

# Подготовка данных
dataframes = []

for file_path in csv_files:
    try:
        # Читаем файл как текст, разбиваем по '|'
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        timestamps = []
        temperatures = []
        
        for line in lines:
            line = line.strip()
            if not line:
                continue
            parts = line.split('|')
            if len(parts) != 2:
                print(f"Пропущена строка в {file_path}: {line}")
                continue
            
            timestamp_str = parts[0].strip()
            temp_str = parts[1].strip().replace('°C', '').strip()
            
            try:
                timestamp = pd.to_datetime(timestamp_str)
                temp = float(temp_str)
                timestamps.append(timestamp)
                temperatures.append(temp)
            except Exception as e:
                print(f"Ошибка разбора строки в {file_path}: {line} | {e}")
                continue
        
        # Создаём DataFrame для файла
        df = pd.DataFrame({
            'timestamp': timestamps,
            'temperature': temperatures,
            'source_file': os.path.basename(file_path)
        })
        dataframes.append(df)
        
    except Exception as e:
        print(f"Ошибка при обработке {file_path}: {e}")

# Объединяем все данные
if not dataframes:
    print("Нет валидных данных для построения графика!")
    exit(1)

all_data = pd.concat(dataframes, ignore_index=True)

# Сортируем по времени
all_data.sort_values('timestamp', inplace=True)

# Строим график
fig = go.Figure()

# Группируем по файлу-источнику
for filename in all_data['source_file'].unique():
    subset = all_data[all_data['source_file'] == filename]
    fig.add_trace(go.Scatter(
        x=subset['timestamp'],
        y=subset['temperature'],
        mode='lines+markers',
        name=filename,
        hovertemplate=(
            '<b>%{y:.1f}°C</b><br />' +
            '%{x|%H:%M %d.%m.%Y}<br />' +
            '<extra></extra>'
        )
    ))

# Настраиваем макет

timestamp1 = datetime.now()
formatted1 = timestamp.strftime('%H:%M:%S %d.%m.%Y')


fig.update_layout(
    title="Температура по данным из термоботов (генерация: " + formatted1 + ")",
    xaxis_title="Время",
    yaxis_title="Температура (°C)",
    hovermode="x",
    legend_title="Источник данных",
    template="simple_white"
)

fig.update_xaxes(
 #   tickformat="%H:%M\n%d.%m.%Y",
    rangeslider_visible=False,
    rangeselector=dict(
        buttons=list([
            dict(count=1, label="1ч", step="hour", stepmode="backward"),
            dict(count=6, label="6ч", step="hour", stepmode="backward"),
            dict(count=1, label="1д", step="day", stepmode="backward"),
            dict(step="all", label="Всё")
        ])
    )
)


# Сохраняем в HTML
fig.write_html(OUTPUT_HTML)


html_str = fig.to_html(
    full_html=True,
    include_plotlyjs='cdn'
)
# Добавляем мета‑тег обновления в <head>
meta_tag = '<meta http-equiv="refresh" content="62">\n'
html_with_meta = html_str.replace('<head>', f'<head>\n{meta_tag}')

print(f"График сохранён в {OUTPUT_HTML}")

 # Сохраняем файл
with open(OUTPUT_HTML, 'w', encoding='utf-8') as f:
    f.write(html_with_meta)

print(f"График обновлён: {OUTPUT_HTML} (с мета‑обновлением)")

