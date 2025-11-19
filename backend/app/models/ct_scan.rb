# Модель для хранения информации о КТ-сканах
# Отвечает за:
# - Хранение метаданных КТ-скана (пациент, дата исследования, модальность)
# - Прикрепление DICOM файла через Active Storage
# - Отслеживание статуса обработки (uploaded, processing, completed, failed)
# - Связь с задачами сегментации и их результатами
class CtScan < ApplicationRecord
  # Связи с задачами сегментации (один КТ-скан может иметь несколько задач)
  has_many :segmentation_tasks, dependent: :destroy
  # Связь с результатами через задачи
  has_many :segmentation_results, through: :segmentation_tasks
  
  # Прикрепление DICOM файла через Active Storage
  has_one_attached :dicom_file
  # Прикрепление изображений срезов (для будущего использования)
  has_many_attached :slice_images
  
  # Валидации
  validates :patient_id, presence: true  # ID пациента (анонимизированный)
  validates :status, presence: true, inclusion: { in: %w[uploaded processing completed failed] }
  validates :modality, presence: true  # Модальность (CT, MR и т.д.)
  
  # Scopes для удобной выборки
  scope :recent, -> { order(created_at: :desc) }  # Последние загруженные
  scope :by_status, ->(status) { where(status: status) }  # По статусу
  
  # Установка значений по умолчанию перед созданием
  before_create :set_default_values
  
  # Проверка статусов
  def processed?
    status == 'completed'  # Обработан ли КТ-скан
  end
  
  def processing?
    status == 'processing'  # Обрабатывается ли сейчас
  end
  
  def failed?
    status == 'failed'  # Завершился ли с ошибкой
  end
  
  private
  
  # Установка значений по умолчанию
  def set_default_values
    self.status ||= 'uploaded'  # Статус по умолчанию - загружен
    self.modality ||= 'CT'  # Модальность по умолчанию - КТ
    self.slice_count ||= 0  # Количество срезов по умолчанию
  end
end
