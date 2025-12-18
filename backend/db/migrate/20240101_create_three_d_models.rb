class CreateThreeDModels < ActiveRecord::Migration[7.0]
  def change
    create_table :three_d_models do |t|
      t.string :name, null: false
      t.references :ct_scan, null: false, foreign_key: true
      t.json :metadata
      t.string :status, default: 'pending'
      t.text :error_message
      t.datetime :generated_at
      
      t.timestamps
    end
  end
end