class CheckoutsController < ApplicationController
  def index
    @day = SchoolDay.parse(params[:day])
    @grade = params[:grade].presence
    @q = params[:q].to_s
    all_visits = Attendance.on(@day)
      .joins(:student)
      .merge(Student.in_grade(@grade))
      .includes(:student)
      .merge(Student.ordered_by_name)
      .order(:checkin, :id)
      .to_a
    matching_student_ids = Student.named(@q).in_grade(@grade).pluck(:id).to_set
    @ready_visits = all_visits.select { |visit| visit.open? && matching_student_ids.include?(visit.student_id) }
    @checked_out_visits = all_visits.reject(&:open?)
    @other_open_days = Attendance.open.where.not(day: @day).distinct.order(:day).pluck(:day)
  end

  def create
    visit = Attendance.open.find(params.expect(:attendance_id))
    time = params[:checkout_time]
    if visit.day < Date.current && !time.to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
      redirect_to checkouts_path(day: visit.day, grade: params[:grade], q: params[:q]), alert: "Choose a valid check-out time for this past date."
      return
    end
    unless visit.check_out(time: time)
      redirect_to checkouts_path(day: visit.day, grade: params[:grade], q: params[:q]), alert: "Check-out time must be after the check-in time."
      return
    end
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
