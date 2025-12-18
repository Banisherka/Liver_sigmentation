class ThreeDModelSerializer
  include FastJsonapi::ObjectSerializer
  
  attributes :id, :name, :status, :generated_at, :created_at, :updated_at
  attribute :model_url do |object|
    if object.model_file.attached?
      Rails.application.routes.url_helpers.url_for(object.model_file)
    end
  end
end