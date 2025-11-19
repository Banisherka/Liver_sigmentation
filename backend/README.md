# Backend API - Сегментация печени на КТ-сканах

REST API для управления сегментацией печени на компьютерных томограммах.

## 📋 Описание

Backend API на Ruby on Rails, который предоставляет RESTful интерфейс для:
- Загрузки DICOM файлов
- Создания и управления задачами сегментации
- Получения результатов с метриками качества
- Скачивания файлов масок сегментации

## 🚀 Установка

### Требования
- Ruby 3.x
- Rails 7.x
- PostgreSQL

### Шаги установки

```bash
# Установка зависимостей
bundle install

# Настройка базы данных
rails db:create db:migrate

# Загрузка начальных данных (опционально)
rails db:seed
```

## 🏃 Запуск

### Development режим

```bash
# Запуск сервера
rails server

# Или через bin/dev (с поддержкой ActionCable)
bin/dev
```

API будет доступно по адресу: `http://localhost:3000`

### Production режим

```bash
# Компиляция ассетов
rails assets:precompile

# Запуск через Puma
bundle exec puma -C config/puma.rb
```

## 📡 API Endpoints

### Health Check

**GET** `/api/v1/health`

Проверка работоспособности API.

**Ответ:**
```json
{
  "status": "ok",
  "message": "API is running",
  "timestamp": "2024-01-01T12:00:00Z",
  "version": "1.0.0"
}
```

### Загрузка DICOM и запуск сегментации

**POST** `/api/v1/segmentation/upload`

Загружает DICOM файл и автоматически запускает сегментацию.

**Параметры:**
- `file` (обязательный) - DICOM файл
- `patient_id` (опциональный) - ID пациента

**Пример запроса:**
```bash
curl -X POST http://localhost:3000/api/v1/segmentation/upload \
  -F "file=@path/to/dicom/file.dcm" \
  -F "patient_id=ANON_12345"
```

**Ответ:**
```json
{
  "success": true,
  "data": {
    "task_id": 1,
    "ct_scan_id": 1,
    "status": "pending",
    "message": "Segmentation task created successfully"
  }
}
```

### Создание задачи сегментации

**POST** `/api/v1/segmentations`

Создает задачу сегментации для существующего КТ-скана.

**Параметры:**
- `ct_scan_id` (обязательный) - ID КТ-скана

**Пример запроса:**
```bash
curl -X POST http://localhost:3000/api/v1/segmentations \
  -H "Content-Type: application/json" \
  -d '{"ct_scan_id": 1}'
```

### Список задач сегментации

**GET** `/api/v1/segmentations`

Получает список всех задач сегментации.

**Параметры:**
- `limit` (опциональный) - Максимальное количество задач (по умолчанию 50)

**Пример запроса:**
```bash
curl http://localhost:3000/api/v1/segmentations?limit=10
```

### Детали задачи

**GET** `/api/v1/segmentations/:id`

Получает детальную информацию о задаче сегментации.

**Пример запроса:**
```bash
curl http://localhost:3000/api/v1/segmentations/1
```

### Результаты сегментации

**GET** `/api/v1/segmentations/:id/result`

Получает результаты сегментации с метриками качества.

**Пример запроса:**
```bash
curl http://localhost:3000/api/v1/segmentations/1/result
```

**Ответ:**
```json
{
  "success": true,
  "data": {
    "task_id": 1,
    "status": "completed",
    "inference_time_ms": 5000,
    "metrics": {
      "dice": 0.95,
      "iou": 0.92,
      "volume_ml": 1450.5,
      "quality_grade": "Excellent",
      "meets_clinical_standards": true
    },
    "summary": {
      "dice": 0.95,
      "iou": 0.92,
      "volume_ml": 1450.5,
      "quality": "Excellent",
      "clinical_grade": true
    }
  }
}
```

### Скачивание маски

**GET** `/api/v1/segmentations/:id/download_mask`

Скачивает файл маски сегментации.

**Пример запроса:**
```bash
curl -O http://localhost:3000/api/v1/segmentations/1/download_mask
```

## 🗄️ База данных

### Модели

#### CtScan
Хранит информацию о КТ-сканах:
- `patient_id` - ID пациента (анонимизированный)
- `study_date` - Дата исследования
- `modality` - Модальность (CT, MR и т.д.)
- `slice_count` - Количество срезов
- `status` - Статус (uploaded, processing, completed, failed)
- `dicom_file` - Прикрепленный DICOM файл (Active Storage)

#### SegmentationTask
Задачи сегментации:
- `ct_scan_id` - Связь с КТ-сканом
- `status` - Статус (pending, processing, completed, failed)
- `started_at` - Время начала обработки
- `completed_at` - Время завершения
- `inference_time_ms` - Время выполнения инференса (мс)
- `error_message` - Сообщение об ошибке (если есть)

#### SegmentationResult
Результаты сегментации:
- `segmentation_task_id` - Связь с задачей
- `dice_coefficient` - Коэффициент Соренсена-Дайса
- `iou_score` - Intersection over Union
- `volume_ml` - Объем печени в миллилитрах
- `metrics` - Дополнительные метрики (JSON)
- `contours` - Данные контуров (JSON)
- `mask_file_attachment` - Файл маски (Active Storage)

## 🔄 Фоновые задачи

Сегментация выполняется асинхронно через фоновые задачи (GoodJob).

### Запуск воркера

```bash
# В development
bundle exec good_job start

# В production (через systemd или supervisor)
bundle exec good_job start --daemonize
```

## 📡 WebSocket обновления

Статус сегментации обновляется в реальном времени через ActionCable.

**Канал:** `segmentation_{ct_scan_id}`

**Формат сообщения:**
```json
{
  "type": "status_update",
  "data": {
    "ct_scan_id": 1,
    "status": "processing",
    "message": "Segmentation started",
    "timestamp": "2024-01-01T12:00:00Z"
  }
}
```

## 🧪 Тестирование

```bash
# Запуск всех тестов
bundle exec rspec

# Запуск конкретного теста
bundle exec rspec spec/models/ct_scan_spec.rb

# С покрытием кода
COVERAGE=true bundle exec rspec
```

## 🔧 Конфигурация

### База данных

Настройка в `config/database.yml`

### Переменные окружения

Создайте файл `config/application.yml` на основе `config/application.yml.example`

## 📝 Логирование

Логи доступны в:
- Development: `log/development.log`
- Production: `log/production.log`

## 🐛 Отладка

```bash
# Rails console
rails console

# Проверка статуса задач
SegmentationTask.all

# Проверка результатов
SegmentationResult.all
```

## 📚 Дополнительная документация

- [Rails Guides](https://guides.rubyonrails.org/)
- [GoodJob Documentation](https://github.com/bensheldon/good_job)

