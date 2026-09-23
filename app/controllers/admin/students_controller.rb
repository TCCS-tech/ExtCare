class Admin::StudentsController < Admin::BaseController
  def index
    load_dashboard
  end

  def create
    @student = Student.new(student_params)
    if @student.save
      redirect_to admin_students_path(filter_params), notice: "#{@student.full_name} added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def new
    @student = Student.new
  end

  def edit
    @student = Student.find(params[:id])
  end

  def update
    @student = Student.find(params[:id])
    attributes = params.expect(student: [ :first_name, :last_name, :grade, :blackbaud_id, :student_id, :guardian_list, :notes, :hidden, :staff, :prepaid_am, :prepaid_pm ])

    if attributes.key?(:hidden)
      if ActiveModel::Type::Boolean.new.cast(attributes[:hidden])
        @student.hide!
        notice = "#{@student.full_name} removed from the lists."
      else
        @student.restore!
        notice = "#{@student.full_name} restored."
      end
      redirect_to admin_students_path(filter_params), notice: notice
    elsif @student.update(attributes)
      redirect_to admin_students_path(filter_params), notice: "#{@student.full_name} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  helper_method :filter_params

  private
    def student_params
      params.expect(student: [ :first_name, :last_name, :grade, :blackbaud_id, :student_id, :guardian_list, :notes, :staff, :prepaid_am, :prepaid_pm ])
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
