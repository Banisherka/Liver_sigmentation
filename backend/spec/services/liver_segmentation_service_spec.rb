require 'rails_helper'

RSpec.describe LiverSegmentationService, type: :service do
  describe '#call' do
    let(:ct_scan) { create(:ct_scan) }
    let(:service) { described_class.new(ct_scan) }

    it 'can be initialized and called' do
      expect(service).to be_a(LiverSegmentationService)
      result = service.call
      expect(result).to be_a(OpenStruct)
    end

    it 'processes segmentation successfully' do
      result = service.call
      
      expect(result.success?).to be true
      expect(result.result).to be_a(SegmentationTask)
      expect(result.result.status).to eq('completed')
    end

    it 'creates segmentation result with metrics' do
      result = service.call
      
      task = result.result
      expect(task.segmentation_result).to be_present
      expect(task.segmentation_result.dice_coefficient).to be >= 0.90
    end
  end
end
