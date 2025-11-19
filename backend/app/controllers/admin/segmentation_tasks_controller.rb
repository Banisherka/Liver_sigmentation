class Admin::SegmentationTasksController < Admin::BaseController
  before_action :set_segmentation_task, only: [:show, :edit, :update, :destroy]

  def index
    @segmentation_tasks = SegmentationTask.page(params[:page]).per(10)
  end

  def show
  end

  def new
    @segmentation_task = SegmentationTask.new
  end

  def create
    @segmentation_task = SegmentationTask.new(segmentation_task_params)

    if @segmentation_task.save
      redirect_to admin_segmentation_task_path(@segmentation_task), notice: 'Segmentation task was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @segmentation_task.update(segmentation_task_params)
      redirect_to admin_segmentation_task_path(@segmentation_task), notice: 'Segmentation task was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @segmentation_task.destroy
    redirect_to admin_segmentation_tasks_path, notice: 'Segmentation task was successfully deleted.'
  end

  private

  def set_segmentation_task
    @segmentation_task = SegmentationTask.find(params[:id])
  end

  def segmentation_task_params
    params.require(:segmentation_task).permit(:status, :started_at, :completed_at, :error_message, :inference_time_ms, :ct_scan_id)
  end
end
