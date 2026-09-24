class Admin::BillingRecordsController < Admin::BaseController
  def index
    @day = SchoolDay.parse(params[:day])
    @records = BillingRecord.where(day: @day).includes(:student).joins(:student).order("students.blackbaud_id", "students.id")
  end
end
