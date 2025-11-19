# Модель задачи сегментации печени
# Отвечает за:
# - Отслеживание статуса выполнения задачи (pending, processing, completed, failed)
# - Хранение времени выполнения инференса нейросети
# - Связь с КТ-сканом и результатом сегментации
# - Управление жизненным циклом задачи
class SegmentationTask < ApplicationRecord
  # Связь с КТ-сканом (задача принадлежит одному КТ-скану)
  belongs_to :ct_scan
  # Связь с результатом (у задачи один результат)
  has_one :segmentation_result, dependent: :destroy
  
  # Валидация статуса задачи
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }
  
  # Scopes для фильтрации по статусу
  scope :pending, -> { where(status: 'pending') }  # Ожидающие обработки
  scope :processing, -> { where(status: 'processing') }  # Обрабатывающиеся
  scope :completed, -> { where(status: 'completed') }  # Завершенные
  scope :failed, -> { where(status: 'failed') }  # Завершенные с ошибкой
  scope :recent, -> { order(created_at: :desc) }  # Последние созданные
  
  # Установка статуса по умолчанию
  before_create :set_default_status
  
  # Проверки статуса задачи
  def pending?
    status == 'pending'  # Ожидает ли обработки
  end
  
  def processing?
    status == 'processing'  # Обрабатывается ли сейчас
  end
  
  def completed?
    status == 'completed'  # Завершена ли успешно
  end
  
  def failed?
    status == 'failed'  # Завершилась ли с ошибкой
  end
  
  # Методы для изменения статуса задачи
  
  # Пометить задачу как обрабатывающуюся
  def mark_as_processing!
    update!(status: 'processing', started_at: Time.current)
  end
  
  # Пометить задачу как завершенную
  def mark_as_completed!
    update!(
      status: 'completed',
      completed_at: Time.current,
      inference_time_ms: calculate_inference_time  # Время инференса в миллисекундах
    )
  end
  
  # Пометить задачу как завершенную с ошибкой
  def mark_as_failed!(error_msg)
    update!(
      status: 'failed',
      error_message: error_msg,  # Сообщение об ошибке
      completed_at: Time.current
    )
  end
  
  # Вычислить длительность выполнения задачи в миллисекундах
  def duration
    return nil unless completed_at && started_at
    ((completed_at - started_at) * 1000).to_i
  end
  
  private
  
  # Установка значений по умолчанию
  def set_default_status
    self.status ||= 'pending'  # Статус по умолчанию - ожидание
    self.inference_time_ms ||= 0  # Время инференса по умолчанию
  end
  
  # Вычисление времени инференса
  def calculate_inference_time
    return inference_time_ms if inference_time_ms&.positive?
    duration || 0
  end
end
