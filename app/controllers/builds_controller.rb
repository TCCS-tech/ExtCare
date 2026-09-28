
class BuildsController < ActionController::Base
  def show
    response.headers["Cache-Control"] = "no-store"
    render json: { version: Rails.application.config.x.build_version }
  end
end
