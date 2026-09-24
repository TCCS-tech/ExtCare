class Admin::ExtendedCareSchedulesController < Admin::BaseController
  def index
    @schedules = ExtendedCareSchedule.order(Arel.sql("day NULLS FIRST"))
    @schedule ||= ExtendedCareSchedule.new
  end

  def create
    @schedule = ExtendedCareSchedule.new(schedule_params)
    if @schedule.save
      redirect_to admin_extended_care_schedules_path, notice: "Schedule saved."
    else
      index
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @schedule = ExtendedCareSchedule.find(params[:id])
    if @schedule.update(schedule_params)
      redirect_to admin_extended_care_schedules_path, notice: "Schedule updated."
    else
      index
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    schedule = ExtendedCareSchedule.find(params[:id])
    schedule.destroy!
    redirect_to admin_extended_care_schedules_path, notice: "Schedule removed."
  end

  private

  def schedule_params
    params.require(:extended_care_schedule).permit(:day, :start_time, :end_time)
  end
end
