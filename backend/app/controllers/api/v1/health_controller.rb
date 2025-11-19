# Контроллер для проверки работоспособности API
# Используется для health checks и мониторинга
class Api::V1::HealthController < Api::BaseController
  # GET /api/v1/health
  # Проверка работоспособности API
  # Возвращает: JSON с информацией о статусе API
  def index
    render json: {
      status: 'ok',  # Статус API
      message: 'API is running',  # Сообщение
      timestamp: Time.current.iso8601,  # Временная метка
      version: '1.0.0'  # Версия API
    }
  end
end
