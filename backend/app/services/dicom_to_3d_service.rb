class DicomTo3dService
  def initialize(ct_scan)
    @ct_scan = ct_scan
  end
  
  def generate
    # 1. Собираем пути к DICOM файлам
    dicom_files = collect_dicom_files
    
    # 2. Генерируем 3D модель через Python
    result = execute_python_script(dicom_files)
    
    # 3. Сохраняем результат
    save_result(result)
  end
  
  private
  
  def collect_dicom_files
    # Предполагаем, что DICOM файлы хранятся в storage
    storage_path = Rails.root.join('storage', 'dicom_files', @ct_scan.id.to_s)
    Dir.glob("#{storage_path}/*.dcm")
  end
  
  def execute_python_script(dicom_files)
    # Вызываем Python скрипт
    script_path = Rails.root.join('scripts', 'generate_3d.py')
    temp_dir = Rails.root.join('tmp', 'dicom_processing', SecureRandom.hex(8))
    
    FileUtils.mkdir_p(temp_dir)
    
    # Копируем файлы во временную директорию
    dicom_files.each_with_index do |file, index|
      FileUtils.cp(file, File.join(temp_dir, "slice_#{index.to_s.rjust(4, '0')}.dcm"))
    end
    
    # Запускаем Python скрипт
    output = `python3 #{script_path} #{temp_dir} 2>&1`
    
    # Проверяем результат
    if $?.success?
      JSON.parse(output)
    else
      raise "3D generation failed: #{output}"
    end
  ensure
    # Очищаем временную директорию
    FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
  end
  
  def save_result(result)
    # Сохраняем STL файл в Active Storage
    stl_path = result['stl_path']
    if File.exist?(stl_path)
      File.open(stl_path) do |file|
        @ct_scan.three_d_models.last.model_file.attach(
          io: file,
          filename: "model_#{@ct_scan.id}.stl",
          content_type: 'application/sla'
        )
      end
    end
  end
end