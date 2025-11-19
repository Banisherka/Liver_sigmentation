# Модель результата сегментации печени
# Отвечает за:
# - Хранение метрик качества сегментации (Dice, IoU, объем и т.д.)
# - Прикрепление файлов результатов (маска, контуры, отчет)
# - Оценку качества сегментации и соответствия клиническим стандартам
# - Предоставление сводной информации о результатах
class SegmentationResult < ApplicationRecord
  # Связь с задачей сегментации
  belongs_to :segmentation_task
  # Связь с КТ-сканом через задачу
  has_one :ct_scan, through: :segmentation_task
  
  # Прикрепление файлов результатов через Active Storage
  has_one_attached :mask_file_attachment  # Файл маски сегментации
  has_one_attached :contour_file  # Файл с контурами
  has_one_attached :report_pdf  # PDF отчет (для будущего использования)
  
  # Валидации метрик
  # Dice Coefficient: от 0 до 1 (чем выше, тем лучше)
  validates :dice_coefficient, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1, allow_nil: true }
  # IoU (Intersection over Union): от 0 до 1
  validates :iou_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1, allow_nil: true }
  # Объем печени в миллилитрах (должен быть положительным)
  validates :volume_ml, numericality: { greater_than: 0, allow_nil: true }
  
  # Scopes для фильтрации
  scope :high_quality, -> { where('dice_coefficient >= ?', 0.90) }  # Высококачественные результаты
  scope :recent, -> { order(created_at: :desc) }  # Последние результаты
  
  # Обеспечение структуры метрик перед сохранением
  before_save :ensure_metrics_structure
  
  # Определение оценки качества на основе Dice Coefficient
  # Excellent: >= 0.90 (клинический стандарт)
  # Good: >= 0.80
  # Fair: >= 0.70
  # Poor: < 0.70
  def quality_grade
    return 'N/A' unless dice_coefficient
    
    if dice_coefficient >= 0.90
      'Excellent'  # Отличное качество
    elsif dice_coefficient >= 0.80
      'Good'  # Хорошее качество
    elsif dice_coefficient >= 0.70
      'Fair'  # Удовлетворительное качество
    else
      'Poor'  # Плохое качество
    end
  end
  
  # Проверка соответствия клиническим стандартам
  # Для клинического использования требуется Dice >= 0.90 и IoU >= 0.90
  def meets_clinical_standards?
    dice_coefficient.present? && dice_coefficient >= 0.90 &&
      iou_score.present? && iou_score >= 0.90
  end
  
  # Сводная информация о результатах
  def summary
    {
      dice: dice_coefficient&.round(4),  # Dice Coefficient
      iou: iou_score&.round(4),  # IoU
      volume_ml: volume_ml&.round(2),  # Объем в миллилитрах
      quality: quality_grade,  # Оценка качества
      clinical_grade: meets_clinical_standards?  # Соответствие клиническим стандартам
    }
  end
  
  private
  
  # Обеспечение наличия структуры для метрик и контуров
  def ensure_metrics_structure
    self.metrics ||= {}  # Дополнительные метрики в формате JSON
    self.contours ||= {}  # Данные контуров в формате JSON
  end
end
