class Admin::NewSchoolYearsController < Admin::BaseController
  before_action :set_rollover, only: %i[show update]
  before_action -> { response.headers["Cache-Control"] = "no-store" }

  def new
    @rollover = Current.user.school_year_rollovers.order(id: :desc).first
    redirect_to admin_new_school_year_path(@rollover) if @rollover && !@rollover.completed? && !@rollover.failed? && !@rollover.interrupted?
  end

  def create
    Current.user.with_lock do
      @rollover = Current.user.school_year_rollovers.order(id: :desc).first
      if !@rollover || @rollover.completed? || @rollover.failed? || @rollover.interrupted? || params[:restart] == "1" && !@rollover.waiting?
        @rollover = Current.user.school_year_rollovers.create!
        SchoolYearBackupJob.perform_later(@rollover)
      end
    end
    redirect_to admin_new_school_year_path(@rollover)
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: { step: wizard_step, message: @rollover.error_message } }
    end
  end

  def update
    @rollover.complete!(confirmation: params[:confirmation])
    redirect_to admin_new_school_year_path(@rollover), notice: "The new school year is ready."
  rescue SchoolYearRollover::NotReady, SchoolYearRollover::StaleBackup => error
    flash.now[:alert] = error.message
    render :show, status: :unprocessable_entity
  rescue ActiveRecord::LockWaitTimeout
    flash.now[:alert] = "The data is busy. Please wait a moment and try again."
    render :show, status: :unprocessable_entity
  end

  private
    def set_rollover
      @rollover = Current.user.school_year_rollovers.find(params[:id])
    end

    def wizard_step
      return "failed" if @rollover.failed? || @rollover.interrupted?
      return "completed" if @rollover.completed?
      return "waiting" if @rollover.waiting?
      @rollover.downloaded_at? ? "confirm" : "download"
    end
    helper_method :wizard_step
end
