class ThreeDGenerationJob < ApplicationJob
  queue_as :default
  
  def perform(three_d_model_id)
    three_d_model = ThreeDModel.find(three_d_model_id)
    ct_scan = three_d_model.ct_scan
    
    begin
      three_d_model.update!(status: 'processing')
      
      # Запускаем генерацию 3D модели
      service = DicomTo3dService.new(ct_scan)
      service.generate
      
      three_d_model.update!(
        status: 'completed',
        generated_at: Time.current
      )
    rescue => e
      three_d_model.update!(
        status: 'failed',
        error_message: e.message
      )
      raise e
    end
  end
end