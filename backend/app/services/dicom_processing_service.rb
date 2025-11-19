# Сервис для обработки DICOM файлов
# Отвечает за:
# - Извлечение метаданных из DICOM файлов
# - Анонимизацию данных пациента
# - Создание записи CtScan в базе данных
# - Прикрепление DICOM файла через Active Storage
# - Оценку количества срезов
class DicomProcessingService < ApplicationService
  attr_reader :file, :patient_id, :error

  # Инициализация сервиса
  # Параметры:
  #   - file: Загруженный DICOM файл
  #   - patient_id: ID пациента (опциональный, будет сгенерирован если не указан)
  def initialize(file:, patient_id: nil)
    @file = file
    @patient_id = patient_id || generate_anonymous_id
    @error = nil
  end

  # Основной метод обработки DICOM файла
  # Возвращает: OpenStruct с результатом (success?, result: CtScan, error)
  def call
    return failure('No file provided') unless file

    process_dicom_file
  rescue StandardError => e
    Rails.logger.error("DICOM processing failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    failure(e.message)
  end

  private

  # Основной процесс обработки DICOM файла
  # Выполняет:
  # 1. Извлечение метаданных
  # 2. Создание записи CtScan
  # 3. Прикрепление DICOM файла
  # 4. Обработку срезов
  def process_dicom_file
    # Извлечение метаданных из DICOM файла
    metadata = extract_metadata
    
    # Создание записи КТ-скана в базе данных
    ct_scan = create_ct_scan(metadata)
    
    # Прикрепление DICOM файла через Active Storage
    attach_dicom_file(ct_scan)
    
    # Обработка срезов (для будущего использования)
    process_slices(ct_scan)
    
    success(ct_scan)
  end

  # Извлечение метаданных из DICOM файла
  # В продакшене использует pydicom или ruby-dicom
  # Сейчас возвращает мок-метаданные на основе анализа файла
  # Возвращает: Hash с метаданными
  def extract_metadata
    filename = file.respond_to?(:original_filename) ? file.original_filename : File.basename(file.path)
    
    {
      patient_id: anonymize_patient_id,  # Анонимизированный ID пациента
      study_date: extract_study_date,  # Дата исследования
      modality: detect_modality(filename),  # Модальность (CT, MR и т.д.)
      slice_count: estimate_slice_count,  # Оценка количества срезов
      series_description: 'CT Abdomen with Contrast',  # Описание серии
      institution_name: 'Anonymous Hospital',  # Название учреждения
      manufacturer: 'Unknown'  # Производитель оборудования
    }
  end

  # Создание записи КТ-скана в базе данных
  # Параметры:
  #   - metadata: Hash с метаданными
  # Возвращает: Объект CtScan
  def create_ct_scan(metadata)
    CtScan.create!(
      patient_id: metadata[:patient_id],
      study_date: metadata[:study_date],
      modality: metadata[:modality],
      slice_count: metadata[:slice_count],
      status: 'uploaded',  # Статус - загружен
      dicom_series: metadata.to_json  # Все метаданные в формате JSON
    )
  end

  # Прикрепление DICOM файла к записи КТ-скана через Active Storage
  # Параметры:
  #   - ct_scan: Объект CtScan
  def attach_dicom_file(ct_scan)
    ct_scan.dicom_file.attach(
      io: file.respond_to?(:read) ? file : File.open(file.path),
      filename: sanitize_filename(file),  # Очищенное имя файла
      content_type: 'application/dicom'  # MIME-тип DICOM
    )
  end

  # Обработка срезов КТ-скана
  # В продакшене извлекает отдельные срезы из DICOM серии
  # Сейчас только логирует информацию
  # Параметры:
  #   - ct_scan: Объект CtScan
  def process_slices(ct_scan)
    Rails.logger.info("Processing #{ct_scan.slice_count} slices for CT scan #{ct_scan.id}")
    
    # TODO: В будущем извлекать PNG/JPG срезы и прикреплять их
    # slice_images = extract_slice_images(ct_scan.dicom_file)
    # ct_scan.slice_images.attach(slice_images)
  end

  # Анонимизация ID пациента
  # Удаляет PHI (Protected Health Information) - заменяет на анонимный ID
  # Возвращает: Анонимизированный ID пациента
  def anonymize_patient_id
    if patient_id =~ /\A[A-Z0-9_-]+\z/i
      # Уже выглядит как анонимный ID
      patient_id
    else
      generate_anonymous_id
    end
  end

  # Генерация анонимного ID пациента
  # Формат: ANON_XXXXXXXX (где X - случайные hex-символы)
  def generate_anonymous_id
    "ANON_#{SecureRandom.hex(8).upcase}"
  end

  # Извлечение даты исследования
  # Пытается извлечь из имени файла или использует текущую дату
  def extract_study_date
    # TODO: Попытаться извлечь из имени файла или DICOM метаданных
    Date.current
  end

  # Определение модальности по имени файла
  # Параметры:
  #   - filename: Имя файла
  # Возвращает: Модальность (CT, MR и т.д.)
  def detect_modality(filename)
    return 'CT' if filename =~ /ct/i
    return 'MR' if filename =~ /mr|mri/i
    'CT' # По умолчанию - КТ
  end

  # Оценка количества срезов на основе размера файла
  # В продакшене читается из DICOM метаданных
  # Возвращает: Оцененное количество срезов
  def estimate_slice_count
    file_size = file.respond_to?(:size) ? file.size : File.size(file.path)
    
    # Грубая оценка: срез 512x512 ≈ 0.5 МБ
    estimated = (file_size / (512 * 1024)).to_i
    [estimated, 1].max # Минимум 1 срез
  end

  # Очистка имени файла от потенциальной PHI
  # Параметры:
  #   - file: Файл
  # Возвращает: Очищенное имя файла
  def sanitize_filename(file)
    name = file.respond_to?(:original_filename) ? file.original_filename : File.basename(file.path)
    # Удаление любой потенциальной PHI из имени файла
    "dicom_#{SecureRandom.hex(4)}#{File.extname(name)}"
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
