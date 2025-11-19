require 'rails_helper'

RSpec.describe SegmentationProcessorJob, type: :job do
  describe '#perform' do
    let(:ct_scan) { create(:ct_scan) }

    it 'processes segmentation successfully' do
      expect {
        SegmentationProcessorJob.perform_now(ct_scan.id)
      }.not_to raise_error
      
      ct_scan.reload
      expect(ct_scan.segmentation_tasks).not_to be_empty
    end

    it 'broadcasts status updates via ActionCable' do
      expect(ActionCable.server).to receive(:broadcast).at_least(:once)
      
      SegmentationProcessorJob.perform_now(ct_scan.id)
    end
  end
end
