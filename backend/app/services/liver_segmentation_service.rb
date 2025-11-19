# Сервис для выполнения сегментации печени на КТ-сканах
# Отвечает за:
# - Создание задачи сегментации
# - Оркестрацию процесса сегментации (предобработка, инференс, постобработка)
# - Интеграцию с Python сервисом нейросети
# - Сохранение результатов с метриками качества
# - Управление статусами задачи и КТ-скана
class LiverSegmentationService < ApplicationService
  attr_reader :ct_scan, :task, :error

  # Инициализация сервиса
  # Параметры:
  #   - ct_scan: Объект CtScan для сегментации
  def initialize(ct_scan)
    @ct_scan = ct_scan
    @error = nil
  end

  # Основной метод выполнения сегментации
  # Возвращает: OpenStruct с результатом (success?, result, error)
  def call
    # Проверка наличия КТ-скана
    return failure('CT scan not found') unless ct_scan
    # Проверка, не обработан ли уже КТ-скан
    return failure('CT scan already processed') if ct_scan.processed?

    # Выполнение в транзакции для обеспечения целостности данных
    ActiveRecord::Base.transaction do
      @task = create_segmentation_task  # Создание задачи
      process_segmentation  # Обработка сегментации
      success(task)  # Возврат успешного результата
    end
  rescue StandardError => e
    # Обработка ошибок
    Rails.logger.error("Segmentation failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    @task&.mark_as_failed!(e.message)  # Пометить задачу как неудачную
    failure(e.message)
  end

  private

  # Создание задачи сегментации
  def create_segmentation_task
    ct_scan.segmentation_tasks.create!(status: 'pending')
  end

  # Основной процесс сегментации
  # Выполняет:
  # 1. Подготовку данных для нейросети
  # 2. Запуск инференса (вызов Python сервиса)
  # 3. Создание записи результата с метриками
  # 4. Обновление статусов
  def process_segmentation
    # Пометить задачу и КТ-скан как обрабатывающиеся
    task.mark_as_processing!
    ct_scan.update!(status: 'processing')

    # Подготовка входных данных для нейросети
    input_data = prepare_input_data
    
    # Запуск инференса нейросети (интеграция с Python сервисом)
    inference_result = run_inference(input_data)
    
    # Создание записи результата с метриками
    create_result(inference_result)
    
    # Обновление статусов на завершенные
    task.mark_as_completed!
    ct_scan.update!(status: 'completed')
  end

  # Подготовка входных данных для нейросети
  # Возвращает: Hash с данными для Python сервиса
  def prepare_input_data
    {
      ct_scan_id: ct_scan.id,
      patient_id: ct_scan.patient_id,
      dicom_path: ct_scan.dicom_file.attached? ? active_storage_path(ct_scan.dicom_file) : nil,  # Путь к DICOM файлу
      slice_count: ct_scan.slice_count,  # Количество срезов
      modality: ct_scan.modality  # Модальность (CT, MR и т.д.)
    }
  end

  # Запуск инференса нейросети
  # В продакшене здесь должен быть вызов Python сервиса
  # Сейчас возвращает мок-данные для тестирования
  # Параметры:
  #   - input_data: Hash с входными данными
  # Возвращает: Hash с результатами инференса (маска, контуры, метрики)
  def run_inference(input_data)
    # TODO: В продакшене здесь должен быть вызов Python сервиса:
    # PythonInferenceService.new.segment_liver(input_data)
    
    Rails.logger.info("Running inference for CT scan #{ct_scan.id}")
    
    # Симуляция инференса с мок-данными (заменить на реальный вызов Python сервиса)
    {
      mask_data: generate_mock_mask,  # Данные маски сегментации
      contours: generate_mock_contours,  # Данные контуров
      metrics: calculate_mock_metrics,  # Метрики качества
      inference_time_ms: rand(5000..15000)  # Время выполнения инференса (мс)
    }
  end

  # Создание записи результата сегментации
  # Параметры:
  #   - inference_result: Hash с результатами инференса
  # Возвращает: Объект SegmentationResult
  def create_result(inference_result)
    # Создание результата с метриками
    result = task.build_segmentation_result(
      dice_coefficient: inference_result[:metrics][:dice],  # Коэффициент Соренсена-Дайса
      iou_score: inference_result[:metrics][:iou],  # Intersection over Union
      volume_ml: inference_result[:metrics][:volume_ml],  # Объем печени в миллилитрах
      metrics: inference_result[:metrics],  # Все метрики в формате JSON
      contours: inference_result[:contours]  # Данные контуров в формате JSON
    )
    
    # Прикрепление файла маски, если он есть
    if inference_result[:mask_data]
      result.mask_file = inference_result[:mask_data][:path]
    end
    
    result.save!
    result
  end

  # Генерация мок-данных маски (для тестирования)
  # В продакшене маска приходит из Python сервиса
  def generate_mock_mask
    {
      format: 'nifti',  # Формат файла маски
      path: 'tmp/masks/mock_mask.nii.gz',  # Путь к файлу
      dimensions: [512, 512, ct_scan.slice_count || 100]  # Размеры маски
    }
  end

  # Генерация мок-данных контуров (для тестирования)
  # В продакшене контуры извлекаются из маски Python сервисом
  def generate_mock_contours
    {
      format: 'json',
      slices: (0...([ct_scan.slice_count, 10].min)).map do |i|
        {
          slice_index: i,
          contour_points: generate_random_contour_points  # Точки контура
        }
      end
    }
  end

  # Генерация случайных точек контура (для тестирования)
  def generate_random_contour_points
    # Генерация простого кругового контура для демонстрации
    center_x = 256
    center_y = 256
    radius = 80 + rand(40)
    
    (0...36).map do |i|
      angle = (i * 10) * Math::PI / 180
      {
        x: (center_x + radius * Math.cos(angle)).round(2),
        y: (center_y + radius * Math.sin(angle)).round(2)
      }
    end
  end

  # Расчет мок-метрик (для тестирования)
  # В продакшене метрики рассчитываются Python сервисом
  # Генерирует реалистичные значения, соответствующие клиническим стандартам (>= 0.90)
  def calculate_mock_metrics
    {
      dice: (0.90 + rand * 0.07).round(4),  # 0.90 - 0.97 (отличное качество)
      iou: (0.89 + rand * 0.08).round(4),    # 0.89 - 0.97
      volume_ml: (1200.0 + rand * 400.0).round(2), # 1200 - 1600 мл (типичный объем печени)
      pixel_accuracy: (0.95 + rand * 0.04).round(4),  # Точность пикселей
      sensitivity: (0.92 + rand * 0.06).round(4),  # Чувствительность
      specificity: (0.96 + rand * 0.03).round(4)  # Специфичность
    }
  end

  # Получение пути к файлу в Active Storage
  # Параметры:
  #   - attachment: Объект Active Storage attachment
  # Возвращает: Путь к файлу на диске
  def active_storage_path(attachment)
    return nil unless attachment.attached?
    
    if attachment.service.respond_to?(:path_for)
      attachment.service.path_for(attachment.key)
    else
      # Для локального хранилища
      Rails.root.join('storage', attachment.key).to_s
    end
  end

  # Возврат успешного результата
  def success(result)
    OpenStruct.new(success?: true, result: result, error: nil)
  end

  # Возврат результата с ошибкой
  def failure(message)
    @error = message
    OpenStruct.new(success?: false, result: nil, error: message)
  end
end
