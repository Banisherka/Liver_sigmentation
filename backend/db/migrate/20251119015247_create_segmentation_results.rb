class CreateSegmentationResults < ActiveRecord::Migration[7.2]
  def change
    create_table :segmentation_results do |t|
      t.references :segmentation_task
      t.string :mask_file
      t.jsonb :contours
      t.jsonb :metrics
      t.decimal :volume_ml
      t.decimal :dice_coefficient
      t.decimal :iou_score


      t.timestamps
    end
  end
end
