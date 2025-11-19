class CreateSegmentationTasks < ActiveRecord::Migration[7.2]
  def change
    create_table :segmentation_tasks do |t|
      t.references :ct_scan
      t.string :status, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.integer :inference_time_ms, default: 0


      t.timestamps
    end
  end
end
