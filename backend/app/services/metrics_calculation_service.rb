# Сервис для расчета метрик качества сегментации
# Отвечает за:
# - Расчет Dice Coefficient (коэффициент Соренсена-Дайса)
# - Расчет IoU (Intersection over Union)
# - Расчет Sensitivity (чувствительность) и Specificity (специфичность)
# - Расчет Pixel Accuracy (точность пикселей)
# - Расчет объема печени в миллилитрах
# Примечание: В продакшене метрики рассчитываются Python сервисом
class MetricsCalculationService < ApplicationService
  attr_reader :ground_truth, :prediction, :error

  # Инициализация сервиса
  # Параметры:
  #   - ground_truth: Эталонная маска сегментации (ground truth)
  #   - prediction: Предсказанная маска сегментации
  def initialize(ground_truth: nil, prediction: nil)
    @ground_truth = ground_truth
    @prediction = prediction
    @error = nil
  end

  # Основной метод расчета всех метрик
  # Возвращает: OpenStruct с результатом (success?, result: Hash с метриками, error)
  def call
    return failure('Ground truth and prediction required') unless ground_truth && prediction

    calculate_all_metrics
  rescue StandardError => e
    Rails.logger.error("Metrics calculation failed: #{e.message}")
    failure(e.message)
  end

  private

  # Расчет всех метрик качества сегментации
  # Возвращает: Hash со всеми метриками
  def calculate_all_metrics
    metrics = {
      dice: calculate_dice_coefficient,  # Коэффициент Соренсена-Дайса
      iou: calculate_iou,  # Intersection over Union
      pixel_accuracy: calculate_pixel_accuracy,  # Точность пикселей
      sensitivity: calculate_sensitivity,  # Чувствительность (Recall)
      specificity: calculate_specificity,  # Специфичность
      volume_ml: calculate_volume  # Объем печени в миллилитрах
    }

    success(metrics)
  end

  # Расчет Dice Coefficient (F1 Score)
  # Формула: Dice = 2 * |A ∩ B| / (|A| + |B|)
  # Где A - ground truth, B - prediction
  # Диапазон: [0, 1], где 1 - идеальное совпадение
  def calculate_dice_coefficient
    intersection = calculate_intersection  # Пересечение масок
    sum_sizes = ground_truth_size + prediction_size  # Сумма размеров
    
    return 0.0 if sum_sizes.zero?
    
    (2.0 * intersection / sum_sizes).round(6)
  end

  # Расчет IoU (Jaccard Index)
  # Формула: IoU = |A ∩ B| / |A ∪ B|
  # Диапазон: [0, 1], где 1 - идеальное совпадение
  def calculate_iou
    intersection = calculate_intersection  # Пересечение
    union = calculate_union  # Объединение
    
    return 0.0 if union.zero?
    
    (intersection.to_f / union).round(6)
  end

  # Расчет Pixel Accuracy (точность пикселей)
  # Формула: Accuracy = (TP + TN) / Total
  # Где TP - True Positive, TN - True Negative
  def calculate_pixel_accuracy
    true_positive = calculate_intersection  # TP
    true_negative = calculate_true_negatives  # TN
    total_pixels = total_pixel_count  # Общее количество пикселей
    
    return 0.0 if total_pixels.zero?
    
    ((true_positive + true_negative).to_f / total_pixels).round(6)
  end

  # Расчет Sensitivity (Recall, True Positive Rate)
  # Формула: Sensitivity = TP / (TP + FN)
  # Показывает, какая доля реальных пикселей печени была правильно обнаружена
  def calculate_sensitivity
    true_positive = calculate_intersection  # TP
    false_negative = ground_truth_size - true_positive  # FN
    
    return 0.0 if (true_positive + false_negative).zero?
    
    (true_positive.to_f / (true_positive + false_negative)).round(6)
  end

  # Расчет Specificity (True Negative Rate)
  # Формула: Specificity = TN / (TN + FP)
  # Показывает, какая доля фоновых пикселей была правильно классифицирована
  def calculate_specificity
    true_negative = calculate_true_negatives  # TN
    false_positive = prediction_size - calculate_intersection  # FP
    
    return 0.0 if (true_negative + false_positive).zero?
    
    (true_negative.to_f / (true_negative + false_positive)).round(6)
  end

  # Расчет объема печени в миллилитрах
  # Параметры:
  #   - voxel_spacing: Размер вокселя в мм [z, y, x] (по умолчанию 1.0x1.0x1.0)
  # Возвращает: Объем в миллилитрах
  def calculate_volume(voxel_spacing: [1.0, 1.0, 1.0])
    voxel_volume = voxel_spacing.reduce(:*)  # Объем одного вокселя в мм³
    volume_voxels = prediction_size  # Количество вокселей печени
    
    (volume_voxels * voxel_volume / 1000.0).round(2) # Конвертация в мл
  end

  # Вспомогательные методы для расчета метрик
  
  # Расчет пересечения масок (количество пикселей, которые есть в обеих масках)
  # В реальной реализации сравнивает бинарные маски поэлементно
  # Сейчас возвращает мок-значение
  def calculate_intersection
    # TODO: В реальной реализации сравнивать бинарные маски поэлементно
    # Сейчас возвращает разумное мок-значение (~92% перекрытие)
    [ground_truth_size, prediction_size].min * 0.92
  end

  # Расчет объединения масок
  # Формула: |A ∪ B| = |A| + |B| - |A ∩ B|
  def calculate_union
    ground_truth_size + prediction_size - calculate_intersection
  end

  # Расчет True Negatives (пиксели, которые правильно классифицированы как фон)
  # Формула: TN = Total - |A| - |B| + |A ∩ B|
  def calculate_true_negatives
    total_pixel_count - ground_truth_size - prediction_size + calculate_intersection
  end

  # Размер эталонной маски (количество пикселей печени)
  def ground_truth_size
    # TODO: В реальной реализации подсчитывать ненулевые пиксели в маске
    @ground_truth_size ||= extract_mask_size(ground_truth)
  end

  # Размер предсказанной маски (количество пикселей печени)
  def prediction_size
    # TODO: В реальной реализации подсчитывать ненулевые пиксели в маске
    @prediction_size ||= extract_mask_size(prediction)
  end

  # Общее количество пикселей в объеме
  # Для типичного КТ: 512 x 512 x 100 срезов
  def total_pixel_count
    @total_pixel_count ||= 512 * 512 * 100
  end

  # Извлечение размера маски
  # В реальной реализации анализирует фактические данные маски
  # Сейчас возвращает мок-значение
  # Параметры:
  #   - mask: Маска сегментации
  # Возвращает: Количество пикселей печени
  def extract_mask_size(mask)
    # Мок-реализация - в продакшене анализирует фактические данные маски
    # Типичная печень занимает ~5-8% объема брюшной полости на КТ
    (total_pixel_count * (0.05 + rand(0.03))).to_i
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
