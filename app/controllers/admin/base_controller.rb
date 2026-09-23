class Admin::BaseController < ApplicationController
  before_action :require_admin

  private
    def require_admin
      redirect_to root_path, alert: "Only admins can open that page." unless Current.user.admin?
    end

    def load_dashboard
      @day = SchoolDay.parse(params[:day])
      @student_q = params[:student_q].to_s
      @attendance_q = params[:attendance_q].to_s
      @show_hidden = params[:show_hidden] == "1"
      @focus = params[:focus].to_s
      @student ||= Student.new
      students = @student_q.blank? ? Student.none : Student.named(@student_q).ordered_by_name
      students = students.visible unless @show_hidden
      @students = students
      @attendances = Attendance.on(@day)
        .joins(:student)
        .merge(Student.named(@attendance_q))
        .includes(:student, :recorded_by)
        .order(:checkin)
    end

    def admin_filter_params
      {
        student_q: @student_q.presence,
        attendance_q: @attendance_q.presence,
        day: @day,
        show_hidden: ("1" if @show_hidden)
      }.compact
    end
    helper_method :admin_filter_params
end
