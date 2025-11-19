FactoryBot.define do
  factory :segmentation_result do
    association :segmentation_task
    mask_file { 'tmp/masks/liver_mask_001.nii.gz' }
    contours { { format: 'json', slices: [] } }
    metrics { { pixel_accuracy: 0.96, sensitivity: 0.94, specificity: 0.98 } }
    volume_ml { 1450.5 }
    dice_coefficient { 0.94 }
    iou_score { 0.89 }

    trait :excellent_quality do
      dice_coefficient { 0.95 }
      iou_score { 0.92 }
      volume_ml { 1500.0 }
    end

    trait :poor_quality do
      dice_coefficient { 0.65 }
      iou_score { 0.50 }
    end
  end
end
