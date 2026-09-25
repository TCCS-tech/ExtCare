class CheckinsController < ApplicationController
  def index
    @day = SchoolDay.parse(params[:day])
    @grade = params[:grade].presence
    @q = params[:q].to_s
    students = Student.visible.in_grade(@grade)
    recent_student_ids = Attendance.where(day: (@day - 4)..@day).select(:student_id)
    ready_students = students.named(@q)
    ready_students = ready_students.where(id: recent_student_ids) if @q.blank?
    @students = ready_students.ordered_by_name.to_a

    @checked_in_students = students
      .where(id: Attendance.open.select(:student_id))
      .ordered_by_name.to_a
    ids = (@students + @checked_in_students).map(&:id).uniq
    @visits_by_student = Attendance.on(@day).where(student_id: ids).order(:checkin).group_by(&:student_id)
    @open_visits = Attendance.open.where(student_id: ids).index_by(&:student_id)
    @ready_students = @students.reject { |student| @open_visits.key?(student.id) }
    @yesterday_ids = Attendance.on(@day - 1).where(student_id: ids).distinct.pluck(:student_id).to_set
    @other_open_days = Attendance.open.where.not(day: @day).distinct.order(:day).pluck(:day)
  end

  def create
    student = Student.visible.find(params.expect(:student_id))
    day = SchoolDay.parse(params[:day])
    if (day < Date.current || params[:checkin_time].present?) && !params[:checkin_time].to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
      redirect_to checkins_path(day: day, grade: params[:grade], q: params[:q]), alert: "Choose a valid check-in time."
      return
    end
    attendance = Attendance.check_in(student: student, by: Current.user, day: day, time: params[:checkin_time])

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
