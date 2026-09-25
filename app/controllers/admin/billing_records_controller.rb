class Admin::BillingRecordsController < Admin::BaseController
  def index
    @day = parse_day(params[:day])
    @month = parse_month(params[:month])
    @grade = params[:grade].presence
    @query = params[:q].to_s.strip
    @sort_direction = %w[asc desc].include?(params[:sort].to_s) ? params[:sort].to_s : "desc"

    records = BillingRecord.includes(:student).joins(:student)
    records = records.merge(Student.in_grade(@grade)) if @grade.present?
    if @month
      records = records.where("EXTRACT(MONTH FROM billing_records.day) = ?", @month)
    elsif @day
      records = records.where(day: @day)
    end

    if @query.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      records = records.where(
        "students.blackbaud_id ILIKE :query OR students.student_id ILIKE :query OR students.first_name ILIKE :query OR students.last_name ILIKE :query",
        query: pattern
      )
    end

    records = records.order(day: @sort_direction, students: { first_name: :asc })
    @total_count = records.count
    @records = (@day || @month || @grade.present? || @query.present?) ? records : records.limit(100)
    @shown_count = @records.size

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

    def parse_month(value)
      month = Integer(value, 10) if value.present?
      month if month&.between?(1, 12)
    rescue ArgumentError, TypeError
      nil
    end
end
