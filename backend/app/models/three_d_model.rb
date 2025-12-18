class ThreeDModel < ApplicationRecord
  belongs_to :ct_scan
  has_one_attached :model_file
  
  enum status: { pending: 'pending', processing: 'processing', completed: 'completed', failed: 'failed' }
  
  validates :name, presence: true
  validates :ct_scan_id, presence: true
  
  after_create :start_generation
  
  private
  
  def start_generation
    ThreeDGenerationJob.perform_later(self.id)
  end
end