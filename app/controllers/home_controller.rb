class HomeController < ApplicationController
  def show
    @open_count = Attendance.open.on(Date.current).count
  end
end
