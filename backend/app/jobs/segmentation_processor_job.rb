# Фоновая задача для асинхронной обработки сегментации печени
# Отвечает за:
# - Асинхронное выполнение сегментации (не блокирует основной поток)
# - Отправку обновлений статуса через ActionCable (WebSocket)
# - Обработку ошибок и повторные попытки
# - Логирование процесса выполнения
# Использование:
#   SegmentationProcessorJob.perform_later(ct_scan_id)
class SegmentationProcessorJob < ApplicationJob
  queue_as :default  # Очередь по умолчанию

  # Выполнение задачи сегментации
  # Параметры:
  #   - ct_scan_id: ID КТ-скана для сегментации
  # Выполняет:
  #   1. Загрузку КТ-скана из базы данных
  #   2. Запуск сервиса сегментации
  #   3. Отправку обновлений статуса через WebSocket
  #   4. Обработку ошибок
  def perform(ct_scan_id)
    # Загрузка КТ-скана
    ct_scan = CtScan.find(ct_scan_id)
    
    Rails.logger.info("Starting segmentation for CT scan #{ct_scan_id}")
    
    # Отправка обновления статуса: начало обработки
    broadcast_status(ct_scan_id, 'processing', 'Segmentation started')
    
    # Запуск сервиса сегментации печени
    # Сервис выполняет:
    # - Создание задачи сегментации
    # - Подготовку данных
    # - Вызов Python сервиса нейросети
    # - Сохранение результатов
    result = LiverSegmentationService.new(ct_scan).call
    
    if result.success?
      task = result.result
      Rails.logger.info("Segmentation completed successfully for CT scan #{ct_scan_id}")
      
      # Отправка обновления статуса: успешное завершение
      broadcast_status(
        ct_scan_id,
        'completed',
        'Segmentation completed successfully',
        task_id: task.id,
        inference_time_ms: task.inference_time_ms  # Время выполнения инференса
      )
    else
      Rails.logger.error("Segmentation failed for CT scan #{ct_scan_id}: #{result.error}")
      
      # Отправка обновления статуса: ошибка
      broadcast_status(
        ct_scan_id,
        'failed',
        result.error
      )
      
      # Повторный выброс исключения для механизма повторов задачи
      raise StandardError, "Segmentation failed: #{result.error}"
    end
  rescue StandardError => e
    # Обработка неожиданных ошибок
    Rails.logger.error("Segmentation job error for CT scan #{ct_scan_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    
    # Отправка обновления статуса: ошибка
    broadcast_status(
      ct_scan_id,
      'failed',
      e.message
    )
    
    # Повторный выброс для мониторинга задач
    raise
  end

  private

  # Отправка обновления статуса через ActionCable (WebSocket)
  # Позволяет клиентам получать обновления статуса в реальном времени
  # Параметры:
  #   - ct_scan_id: ID КТ-скана
  #   - status: Статус (processing, completed, failed)
  #   - message: Сообщение о статусе
  #   - **extra_data: Дополнительные данные (task_id, inference_time_ms и т.д.)
  def broadcast_status(ct_scan_id, status, message, **extra_data)
    ActionCable.server.broadcast(
      "segmentation_#{ct_scan_id}",  # Канал WebSocket для конкретного КТ-скана
      {
        type: 'status_update',  # Тип сообщения
        data: {
          ct_scan_id: ct_scan_id,
          status: status,  # Статус задачи
          message: message,  # Сообщение
          timestamp: Time.current.iso8601  # Временная метка в формате ISO8601
        }.merge(extra_data)  # Объединение с дополнительными данными
      }
    )
  end
end
