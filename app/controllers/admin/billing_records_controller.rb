class Admin::BillingRecordsController < Admin::BaseController
  def index
    @day = parse_day(params[:day])
    @query = params[:q].to_s.strip

    records = BillingRecord.includes(:student).joins(:student)
    records = records.where(day: @day) if @day

    if @query.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      records = records.where(
        "students.blackbaud_id ILIKE :query OR students.student_id ILIKE :query OR students.first_name ILIKE :query OR students.last_name ILIKE :query",
        query: pattern
      )
    end

    records = records.order(day: :desc, id: :desc)
    @records = (@day || @query.present?) ? records : records.limit(100)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  private
    def parse_day(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end
end
