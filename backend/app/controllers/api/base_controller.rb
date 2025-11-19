# Базовый контроллер для всех API endpoints
# Отвечает за:
# - Настройку базовой функциональности для API контроллеров
# - Обработку ошибок через FriendlyErrorHandlingConcern
# Примечание: ActionController::API не включает CSRF защиту по умолчанию
class Api::BaseController < ActionController::API
  # Использование единой обработки ошибок
  include FriendlyErrorHandlingConcern
end
