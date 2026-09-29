class Admin::NewSchoolYears::DownloadsController < Admin::BaseController
  def create
    rollover = Current.user.school_year_rollovers.find(params[:new_school_year_id])
    rollover.record_download!
    response.headers["Cache-Control"] = "no-store"
    send_file rollover.backup_path, filename: rollover.backup_filename,
      type: "application/zip", disposition: "attachment"
  rescue SchoolYearRollover::NotReady => error
    redirect_to admin_new_school_year_path(rollover), alert: error.message
  end
end
