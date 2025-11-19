class Admin::CtScansController < Admin::BaseController
  before_action :set_ct_scan, only: [:show, :edit, :update, :destroy]

  def index
    @ct_scans = CtScan.page(params[:page]).per(10)
  end

  def show
  end

  def new
    @ct_scan = CtScan.new
  end

  def create
    @ct_scan = CtScan.new(ct_scan_params)

    if @ct_scan.save
      redirect_to admin_ct_scan_path(@ct_scan), notice: 'Ct scan was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @ct_scan.update(ct_scan_params)
      redirect_to admin_ct_scan_path(@ct_scan), notice: 'Ct scan was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @ct_scan.destroy
    redirect_to admin_ct_scans_path, notice: 'Ct scan was successfully deleted.'
  end

  private

  def set_ct_scan
    @ct_scan = CtScan.find(params[:id])
  end

  def ct_scan_params
    params.require(:ct_scan).permit(:patient_id, :dicom_series, :study_date, :modality, :slice_count, :status, :dicom_file, slice_images: [])
  end
end
