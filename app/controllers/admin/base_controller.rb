class Admin::BaseController < ApplicationController
  before_action :require_admin

  private
    def require_admin
      redirect_to root_path, alert: "Only admins can open that page." unless Current.user.admin?
    end

    def load_dashboard
      @day = SchoolDay.parse(params[:day])
      @student_q = params[:student_q].to_s
      @grade = params[:grade].presence
      @billing_category = params[:billing_category].presence
      @billing_category = nil unless @billing_category == "all" || Student::FLAGS.any? { |attribute, _| attribute == @billing_category }
      @attendance_q = params[:attendance_q].to_s
      @show_hidden = params[:show_hidden] == "1"
      @focus = params[:focus].to_s
      @student ||= Student.new
      students = if @student_q.blank? && @grade.blank? && @billing_category.blank?
        Student.none
      else
        Student.named(@student_q).in_grade(@grade).ordered_by_name
      end
      if @billing_category == "prepaid_pm"
        students = students.where(prepaid_pm: true, prepaid_am: false)
      elsif @billing_category.present? && @billing_category != "all"
        students = students.where(@billing_category => true)
      end
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
        grade: @grade,
        billing_category: @billing_category,
        attendance_q: @attendance_q.presence,
        day: @day,
        show_hidden: ("1" if @show_hidden)
      }.compact
    end
    helper_method :admin_filter_params
end
