class CheckoutsController < ApplicationController
  def index
    @day = SchoolDay.parse(params[:day])
    @grade = params[:grade].presence
    @q = params[:q].to_s
    @visits = Attendance.open.on(@day)
      .joins(:student)
      .merge(Student.named(@q).in_grade(@grade))
      .includes(:student)
      .order(Arel.sql("lower(students.last_name), lower(students.first_name)"))
    @other_open_days = Attendance.open.where.not(day: @day).distinct.order(:day).pluck(:day)
  end

  def create
    visit = Attendance.open.find(params.expect(:attendance_id))
    visit.check_out(by: Current.user)
    @visit = visit

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to checkouts_path(day: visit.day, grade: params[:grade], q: params[:q]) }
    end
  end
end
