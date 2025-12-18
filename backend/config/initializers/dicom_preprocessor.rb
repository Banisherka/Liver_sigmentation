# config/initializers/dicom_preprocessor.rb

require 'open3'

class DicomPreprocessor
  PYTHON_SCRIPT = Rails.root.join('scripts', 'dicom_processing.py').to_s
  
  def self.preprocess(dicom_path, output_dir)
    # Проверяем наличие Python и зависимостей
    unless python_available?
      raise "Python 3 not available. Please install Python 3.8+"
    end
    
    # Создаем команду для запуска Python скрипта
    cmd = "python3 #{PYTHON_SCRIPT} --input #{dicom_path} --output #{output_dir}"
    
    # Запускаем Python скрипт
    stdout, stderr, status = Open3.capture3(cmd)
    
    if status.success?
      JSON.parse(stdout)
    else
      raise "DICOM preprocessing failed: #{stderr}"
    end
  end
  
  def self.python_available?
    system('python3 --version > /dev/null 2>&1')
  end
  
  def self.install_dependencies
    requirements = Rails.root.join('requirements.txt').to_s
    system("pip3 install -r #{requirements}")
  end
end

# Проверка при старте приложения
Rails.application.config.after_initialize do
  if DicomPreprocessor.python_available?
    Rails.logger.info "Python 3 is available for DICOM processing"
  else
    Rails.logger.warn "Python 3 is not available. DICOM preprocessing will not work."
  end
end