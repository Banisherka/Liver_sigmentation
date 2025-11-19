class CreateCtScans < ActiveRecord::Migration[7.2]
  def change
    create_table :ct_scans do |t|
      t.string :patient_id
      t.text :dicom_series
      t.date :study_date
      t.string :modality, default: "CT"
      t.integer :slice_count, default: 0
      t.string :status, default: "uploaded"


      t.timestamps
    end
  end
end
