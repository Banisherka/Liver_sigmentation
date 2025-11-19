FactoryBot.define do
  factory :segmentation_task do
    association :ct_scan
    status { 'pending' }
    started_at { nil }
    completed_at { nil }
    error_message { nil }
    inference_time_ms { 0 }

    trait :processing do
      status { 'processing' }
      started_at { Time.current }
    end

    trait :completed do
      status { 'completed' }
      started_at { 1.minute.ago }
      completed_at { Time.current }
      inference_time_ms { 8500 }
    end

    trait :failed do
      status { 'failed' }
      started_at { 1.minute.ago }
      completed_at { Time.current }
      error_message { 'Segmentation failed' }
    end
  end
end
