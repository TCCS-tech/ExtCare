class CheckoutsController < ApplicationController
  def index
    @day = SchoolDay.parse(params[:day])
    @grade = params[:grade].presence
    @q = params[:q].to_s
    @visits = Attendance.on(@day)
      .joins(:student)
      .merge(Student.named(@q).in_grade(@grade))
      .includes(:student)
      .merge(Student.ordered_by_name)
      .order(:checkin, :id)
    @ready_visits, @checked_out_visits = @visits.partition(&:open?)
    @other_open_days = Attendance.open.where.not(day: @day).distinct.order(:day).pluck(:day)
  end

  def create
    visit = Attendance.open.find(params.expect(:attendance_id))
    visit.check_out
    @visit = visit

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to checkouts_path(day: visit.day, grade: params[:grade], q: params[:q]) }
    end
  end

  def update
    @visit = Attendance.find(params[:id])
    @visit.update!(attendance_params)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to checkouts_path(day: @visit.day, grade: params[:grade], q: params[:q]) }
    end
  end

  private

  def attendance_params
    params.require(:attendance).permit(:pickup_notes)
  end
end
