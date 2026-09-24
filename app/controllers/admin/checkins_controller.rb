class Admin::CheckinsController < Admin::BaseController
  def index
    load_dashboard
  end

  def destroy
    attendance = Attendance.find(params[:id])
    attendance.destroy!

    redirect_to admin_checkins_path(day: params[:day], attendance_q: params[:attendance_q], student_q: params[:student_q], show_hidden: params[:show_hidden]),
      notice: "Check-in deleted."
  end

  def edit
    @attendance = Attendance.find(params[:id])
    @users = User.order(:email)
  end

  def update
    @attendance = Attendance.find(params[:id])
    @users = User.order(:email)

    if @attendance.update(attendance_params)
      redirect_to admin_checkins_path(day: params[:day] || @attendance.day, attendance_q: params[:attendance_q]),
        notice: "Check-in updated."
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::StatementInvalid => error
    raise unless error.cause.is_a?(PG::CheckViolation)

    if error.cause.message.include?("must be at or after checkin")
      @attendance.errors.add(:checkout, "must be at or after the check-in time.")
    else
      @attendance.errors.add(:base, "This attendance record conflicts with an attendance rule. Review the date and times, then try again.")
    end
    render :edit, status: :unprocessable_entity
  end

  private
    def attendance_params
      params.require(:attendance).permit(:day, :checkin, :checkout, :checkin_by, :pickup_notes)
    end
end
