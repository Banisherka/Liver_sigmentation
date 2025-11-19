require 'rails_helper'

RSpec.describe DicomProcessingService do
  describe '#call' do
    let(:mock_file) do
      file = Tempfile.new(['test', '.dcm'])
      file.write('MOCK DICOM DATA')
      file.rewind
      file
    end

    after do
      mock_file.close
      mock_file.unlink
    end

    let(:service) { described_class.new(file: mock_file, patient_id: 'TEST_001') }

    it 'can be initialized and called' do
      expect(service).to be_a(DicomProcessingService)
      result = service.call
      expect(result).to be_a(OpenStruct)
    end

    it 'processes DICOM file successfully' do
      result = service.call
      
      expect(result.success?).to be true
      expect(result.result).to be_a(CtScan)
      expect(result.result.patient_id).to eq('TEST_001')
    end

    it 'generates anonymous patient ID when not provided' do
      service_without_id = described_class.new(file: mock_file)
      result = service_without_id.call
      
      expect(result.success?).to be true
      expect(result.result.patient_id).to match(/\AANON_[A-F0-9]+\z/)
    end
  end
end
