# Маршруты приложения для API сегментации печени на КТ-сканах
# Все маршруты возвращают JSON, фронтенд удален

Rails.application.routes.draw do
  # ============================================
  # API маршруты для сегментации печени
  # ============================================
  namespace :api do
    namespace :v1 do
      # Проверка работоспособности API
      get 'health', to: 'health#index'
      
      # Маршруты для работы с сегментацией
      # POST /api/v1/segmentation/upload - загрузка DICOM файла и запуск сегментации
      post 'segmentation/upload', to: 'segmentations#upload'
      
      # RESTful ресурсы для управления задачами сегментации
      resources :segmentations, only: [:create, :show, :index] do
        member do
          # GET /api/v1/segmentations/:id/result - получить результаты с метриками
          get :result
          # GET /api/v1/segmentations/:id/download_mask - скачать файл маски
          get :download_mask
        end
      end
    end
  end

  # WebSocket для обновлений статуса сегментации в реальном времени
  mount ActionCable.server => '/cable'

  # Обработка всех несуществующих маршрутов (404) - должен быть последним
  match '*path', to: 'application#handle_routing_error', via: :all,
    constraints: lambda { |request|
      !request.path.start_with?('/rails/active_storage')
    }
end
