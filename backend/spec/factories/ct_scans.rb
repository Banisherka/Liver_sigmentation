FactoryBot.define do
  factory :ct_scan do
    sequence(:patient_id) { |n| "PATIENT_#{n.to_s.rjust(5, '0')}" }
    dicom_series { { series_description: 'CT Abdomen' }.to_json }
    study_date { Date.current }
    modality { 'CT' }
    slice_count { 100 }
    status { 'uploaded' }
  end
end
