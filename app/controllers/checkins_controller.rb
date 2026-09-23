class CheckinsController < ApplicationController
  def index
    @day = SchoolDay.parse(params[:day])
    @grade = params[:grade].presence
    @q = params[:q].to_s
    @students = Student.visible.named(@q).in_grade(@grade).ordered_for_checkin(@day).to_a
    ids = @students.map(&:id)
    @visits_by_student = Attendance.on(@day).where(student_id: ids).order(:checkin).group_by(&:student_id)
    @open_visits = Attendance.open.where(student_id: ids).index_by(&:student_id)
    @yesterday_ids = Attendance.on(@day - 1).where(student_id: ids).distinct.pluck(:student_id).to_set
  end

  def create
    student = Student.visible.find(params.expect(:student_id))
    day = SchoolDay.parse(params[:day])
    attendance = Attendance.check_in(student: student, by: Current.user, day: day)

    if attendance.persisted?
      @student = student
      @day = day
      @grade = params[:grade].presence
      @q = params[:q].to_s
      @visits = student.attendances.on(day).order(:checkin)
      @open_visit = student.attendances.open.first
      @here_yesterday = student.attendances.on(day - 1).exists?
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to checkins_path(day: day, grade: @grade, q: @q) }
      end
    else
      redirect_to checkins_path(day: day, grade: params[:grade], q: params[:q]),
        alert: attendance.errors.full_messages.to_sentence
    end
  end
end
