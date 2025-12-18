module Api
  module V1
    class ThreeDModelsController < ApplicationController
      before_action :set_ct_scan
      before_action :set_three_d_model, only: [:show, :update, :destroy]
      
      # GET /api/v1/ct_scans/:ct_scan_id/three_d_models
      def index
        @three_d_models = @ct_scan.three_d_models
        render json: @three_d_models
      end
      
      # POST /api/v1/ct_scans/:ct_scan_id/three_d_models
      def create
        @three_d_model = @ct_scan.three_d_models.build(three_d_model_params)
        
        if @three_d_model.save
          render json: @three_d_model, status: :created
        else
          render json: @three_d_model.errors, status: :unprocessable_entity
        end
      end
      
      # GET /api/v1/ct_scans/:ct_scan_id/three_d_models/:id
      def show
        render json: @three_d_model
      end
      
      # POST /api/v1/ct_scans/:ct_scan_id/generate_3d
      def generate
        @three_d_model = @ct_scan.three_d_models.create!(
          name: "3D Model #{Time.now.strftime('%Y%m%d_%H%M%S')}",
          status: 'pending'
        )
        
        render json: @three_d_model, status: :created
      end
      
      private
      
      def set_ct_scan
        @ct_scan = CtScan.find(params[:ct_scan_id])
      end
      
      def set_three_d_model
        @three_d_model = @ct_scan.three_d_models.find(params[:id])
      end
      
      def three_d_model_params
        params.require(:three_d_model).permit(:name)
      end
    end
  end
end