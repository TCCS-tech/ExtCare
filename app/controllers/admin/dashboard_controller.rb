class Admin::DashboardController < Admin::BaseController
  def show
    load_dashboard
  end

  def clear_attendance
    unless Rails.env.development?
      redirect_to admin_root_path, alert: "This action is only available in development."
      return
    end

    deleted_count = Attendance.delete_all
    redirect_to admin_root_path, notice: "Deleted #{deleted_count} attendance records."
  end
end
