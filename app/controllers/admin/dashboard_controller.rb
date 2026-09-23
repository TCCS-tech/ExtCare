class Admin::DashboardController < Admin::BaseController
  def show
    load_dashboard
  end
end
