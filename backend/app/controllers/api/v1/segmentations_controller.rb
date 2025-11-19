# Контроллер API для управления сегментацией печени
# Отвечает за:
# - Загрузку DICOM файлов и создание задач сегментации
# - Получение списка и деталей задач сегментации
# - Получение результатов с метриками качества
# - Скачивание файлов масок сегментации
class Api::V1::SegmentationsController < Api::BaseController
  # Установка КТ-скана перед определенными действиями
  before_action :set_ct_scan, only: [:show, :result, :download_mask]

  # POST /api/v1/segmentation/upload
  # Загрузка DICOM файла и автоматический запуск сегментации
  # Параметры:
  #   - file: DICOM файл (обязательный)
  #   - patient_id: ID пациента (опциональный, будет сгенерирован если не указан)
  # Возвращает: JSON с информацией о созданной задаче
  def upload
    # Проверка наличия файла
    unless params[:file].present?
      return render_error('File parameter required', status: :bad_request)
    end

    # Обработка DICOM файла через сервис
    # Сервис извлекает метаданные, создает запись CtScan и прикрепляет файл
    result = DicomProcessingService.new(
      file: params[:file],
      patient_id: params[:patient_id]
    ).call

    # Проверка успешности обработки DICOM
    unless result.success?
      return render_error(result.error, status: :unprocessable_entity)
    end

    ct_scan = result.result

    # Запуск сегментации печени для загруженного КТ-скана
    # Сервис создает задачу, запускает нейросеть и сохраняет результаты
    segmentation_result = LiverSegmentationService.new(ct_scan).call

    # Проверка успешности сегментации
    unless segmentation_result.success?
      return render_error(segmentation_result.error, status: :unprocessable_entity)
    end

    task = segmentation_result.result

    # Возврат информации о созданной задаче
    render_success(
      {
        task_id: task.id,
        ct_scan_id: ct_scan.id,
        status: task.status,
        message: 'Segmentation task created successfully'
      },
      status: :created
    )
  end

  # POST /api/v1/segmentations
  # Создание задачи сегментации для существующего КТ-скана
  # Параметры:
  #   - ct_scan_id: ID существующего КТ-скана (обязательный)
  # Возвращает: JSON с информацией о созданной задаче
  def create
    # Проверка наличия ID КТ-скана
    unless params[:ct_scan_id].present?
      return render_error('ct_scan_id required', status: :bad_request)
    end

    # Поиск КТ-скана
    ct_scan = CtScan.find_by(id: params[:ct_scan_id])
    unless ct_scan
      return render_error('CT scan not found', status: :not_found)
    end

    # Запуск сегментации
    result = LiverSegmentationService.new(ct_scan).call

    unless result.success?
      return render_error(result.error, status: :unprocessable_entity)
    end

    task = result.result

    render_success(
      {
        task_id: task.id,
        status: task.status,
        created_at: task.created_at
      },
      status: :created
    )
  end

  # GET /api/v1/segmentations
  # Получение списка всех задач сегментации
  # Параметры:
  #   - limit: Максимальное количество задач (по умолчанию 50)
  # Возвращает: JSON со списком задач
  def index
    # Загрузка задач с предзагрузкой связанных данных (eager loading)
    tasks = SegmentationTask.includes(:ct_scan, :segmentation_result)
                            .order(created_at: :desc)  # Сначала последние
                            .limit(params[:limit] || 50)  # Ограничение количества

    # Возврат списка задач
    render_success({
      tasks: tasks.map { |task| task_summary(task) }
    })
  end

  # GET /api/v1/segmentations/:id
  # Получение детальной информации о задаче сегментации
  # Параметры:
  #   - id: ID задачи сегментации
  # Возвращает: JSON с детальной информацией о задаче
  def show
    # Поиск задачи с предзагрузкой результата
    task = SegmentationTask.includes(:segmentation_result).find_by(id: params[:id])
    
    unless task
      return render_error('Segmentation task not found', status: :not_found)
    end

    # Возврат детальной информации
    render_success(task_detail(task))
  end

  # GET /api/v1/segmentations/:id/result
  # Получение результатов сегментации с метриками качества
  # Параметры:
  #   - id: ID задачи сегментации
  # Возвращает: JSON с результатами и метриками (Dice, IoU, объем и т.д.)
  def result
    # Поиск задачи
    task = SegmentationTask.includes(:segmentation_result).find_by(id: params[:id])
    
    unless task
      return render_error('Segmentation task not found', status: :not_found)
    end

    # Проверка завершенности задачи
    unless task.completed?
      return render_error('Segmentation not completed', status: :unprocessable_entity)
    end

    result = task.segmentation_result
    unless result
      return render_error('Segmentation result not found', status: :not_found)
    end

    # Возврат результатов с метриками
    render_success({
      task_id: task.id,
      status: task.status,
      inference_time_ms: task.inference_time_ms,  # Время выполнения инференса
      mask_file: result.mask_file,  # Путь к файлу маски
      contours: result.contours,  # Данные контуров
      metrics: {
        dice: result.dice_coefficient,  # Коэффициент Соренсена-Дайса
        iou: result.iou_score,  # Intersection over Union
        volume_ml: result.volume_ml,  # Объем печени в миллилитрах
        quality_grade: result.quality_grade,  # Оценка качества (Excellent/Good/Fair/Poor)
        meets_clinical_standards: result.meets_clinical_standards?  # Соответствие клиническим стандартам
      },
      summary: result.summary  # Сводная информация
    })
  end

  # GET /api/v1/segmentations/:id/download_mask
  # Скачивание файла маски сегментации
  # Параметры:
  #   - id: ID задачи сегментации
  # Возвращает: Файл маски для скачивания
  def download_mask
    # Поиск задачи
    task = SegmentationTask.includes(:segmentation_result).find_by(id: params[:id])
    
    # Проверка завершенности задачи
    unless task&.completed?
      return render_error('Segmentation not completed', status: :unprocessable_entity)
    end

    result = task.segmentation_result
    # Проверка наличия прикрепленного файла маски
    if result&.mask_file_attachment&.attached?
      # Перенаправление на скачивание файла через Active Storage
      redirect_to rails_blob_path(result.mask_file_attachment, disposition: 'attachment')
    else
      render_error('Mask file not available', status: :not_found)
    end
  end

  private

  # Установка КТ-скана из параметров
  def set_ct_scan
    @ct_scan = CtScan.find_by(id: params[:ct_scan_id])
  end

  # Формирование краткой информации о задаче
  def task_summary(task)
    {
      id: task.id,
      ct_scan_id: task.ct_scan_id,
      status: task.status,  # pending, processing, completed, failed
      created_at: task.created_at,
      started_at: task.started_at,
      completed_at: task.completed_at,
      inference_time_ms: task.inference_time_ms,  # Время инференса в миллисекундах
      has_result: task.segmentation_result.present?  # Есть ли результат
    }
  end

  # Формирование детальной информации о задаче
  def task_detail(task)
    {
      id: task.id,
      ct_scan: {
        id: task.ct_scan.id,
        patient_id: task.ct_scan.patient_id,
        study_date: task.ct_scan.study_date,
        modality: task.ct_scan.modality,
        slice_count: task.ct_scan.slice_count
      },
      status: task.status,
      created_at: task.created_at,
      started_at: task.started_at,
      completed_at: task.completed_at,
      inference_time_ms: task.inference_time_ms,
      error_message: task.error_message,  # Сообщение об ошибке (если есть)
      result: task.segmentation_result ? result_summary(task.segmentation_result) : nil
    }
  end

  # Формирование краткой информации о результате
  def result_summary(result)
    {
      dice_coefficient: result.dice_coefficient,
      iou_score: result.iou_score,
      volume_ml: result.volume_ml,
      quality_grade: result.quality_grade,
      meets_clinical_standards: result.meets_clinical_standards?
    }
  end

  # Рендеринг успешного ответа в формате JSON
  def render_success(data, status: :ok)
    render json: { success: true, data: data }, status: status
  end

  # Рендеринг ответа с ошибкой в формате JSON
  def render_error(message, status: :unprocessable_entity)
    render json: { success: false, error: message }, status: status
  end
end
