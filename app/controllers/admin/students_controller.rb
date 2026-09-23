class Admin::StudentsController < Admin::BaseController
  def create
    @student = Student.new(student_params)
    if @student.save
      redirect_to admin_root_path(filter_params), notice: "#{@student.full_name} added."
    else
      load_dashboard
      render "admin/dashboard/show", status: :unprocessable_entity
    end
  end

  def update
    student = Student.find(params[:id])
    if ActiveModel::Type::Boolean.new.cast(visibility_params[:hidden])
      student.hide!
      redirect_to admin_root_path(filter_params), notice: "#{student.full_name} removed from the lists."
    else
      student.restore!
      redirect_to admin_root_path(filter_params), notice: "#{student.full_name} restored."
    end
  end

  private
    def student_params
      params.expect(student: [ :first_name, :last_name, :grade, :blackbaud_id, :guardian_list ])
    end

    def visibility_params
      params.expect(student: [ :hidden ])
    end

    def filter_params
      {
        student_q: params[:student_q].presence,
        attendance_q: params[:attendance_q].presence,
        day: params[:day].presence,
        show_hidden: params[:show_hidden].presence,
        focus: params[:focus].presence
      }.compact
    end
end
