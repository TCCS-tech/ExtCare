class Admin::DashboardController < Admin::BaseController
  def show
    load_dashboard
  end

  # Dev reset. Attendance and the billing rows derived from it clear together:
  # charges left behind would keep billing visits that no longer exist.
  def clear_attendance
    unless Rails.env.development?
      redirect_to admin_root_path, alert: "This action is only available in development."
      return
    end

    counts = ActiveRecord::Base.transaction do
      { visits: Attendance.delete_all, billing: BillingRecord.delete_all }
    end

    redirect_to admin_root_path,
      notice: "Deleted #{counts[:visits]} attendance records and #{counts[:billing]} billing records."
  end
end
