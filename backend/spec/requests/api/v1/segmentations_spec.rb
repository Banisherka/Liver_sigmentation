require 'rails_helper'

RSpec.describe "Api::V1::Segmentations", type: :request do
  let(:ct_scan) { create(:ct_scan) }

  describe "POST /api/v1/segmentation/upload" do
    xit "uploads DICOM file and creates segmentation task" do
      # Skipped - requires file upload infrastructure
      # Create a mock file
      file = fixture_file_upload('spec/fixtures/files/mock_dicom.dcm', 'application/dicom')
      
      post '/api/v1/segmentation/upload', params: { file: file, patient_id: 'TEST_001' }
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['data']).to have_key('task_id')
      expect(json['data']).to have_key('ct_scan_id')
    end

    it "returns error when file is missing" do
      post '/api/v1/segmentation/upload', params: { patient_id: 'TEST_001' }
      
      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
      expect(json['error']).to be_present
    end
  end

  describe "POST /api/v1/segmentations" do
    it "creates segmentation task for existing CT scan" do
      post '/api/v1/segmentations', params: { ct_scan_id: ct_scan.id }
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['data']['task_id']).to be_present
    end

    it "returns error when CT scan not found" do
      post '/api/v1/segmentations', params: { ct_scan_id: 99999 }
      
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
    end
  end

  describe "GET /api/v1/segmentations" do
    let!(:task1) { create(:segmentation_task, ct_scan: ct_scan) }
    let!(:task2) { create(:segmentation_task, ct_scan: ct_scan) }

    it "lists all segmentation tasks" do
      get '/api/v1/segmentations'
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['data']['tasks']).to be_an(Array)
      expect(json['data']['tasks'].size).to be >= 2
    end
  end

  describe "GET /api/v1/segmentations/:id" do
    let(:task) { create(:segmentation_task, ct_scan: ct_scan) }

    it "shows segmentation task details" do
      get "/api/v1/segmentations/#{task.id}"
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['data']['id']).to eq(task.id)
      expect(json['data']['ct_scan']).to be_present
    end

    it "returns not found for invalid ID" do
      get '/api/v1/segmentations/99999'
      
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json['success']).to be false
    end
  end

  describe "GET /api/v1/segmentations/:id/result" do
    let(:task) { create(:segmentation_task, ct_scan: ct_scan, status: 'completed') }
    let!(:result) { create(:segmentation_result, segmentation_task: task, dice_coefficient: 0.94, iou_score: 0.89) }

    it "returns segmentation result with metrics" do
      get "/api/v1/segmentations/#{task.id}/result"
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['data']['metrics']).to be_present
      expect(json['data']['metrics']['dice'].to_f).to be_within(0.01).of(0.94)
    end

    it "returns error for incomplete segmentation" do
      pending_task = create(:segmentation_task, ct_scan: ct_scan, status: 'pending')
      get "/api/v1/segmentations/#{pending_task.id}/result"
      
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
