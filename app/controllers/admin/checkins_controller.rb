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
end
