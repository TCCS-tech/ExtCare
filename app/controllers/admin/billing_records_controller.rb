class Admin::BillingRecordsController < Admin::BaseController
  require "stringio"
  require "zip"

  EXPORT_HEADERS = [
    "Family Id", "School Student Id", "Student Last Name", "Student First Name",
    "Grade Level", "Account Status", "Billing name", "Amount", "Custom Fee Description"
  ].freeze

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

  def export
    month = parse_month(params[:month])
    return head :unprocessable_entity unless month

    month_name = Date::MONTHNAMES[month]
    records = BillingRecord.includes(:student).joins(:student)
      .where("EXTRACT(MONTH FROM billing_records.day) = ?", month)
      .order(:day, "students.last_name", "students.first_name")

    rows = records.map do |record|
      student = record.student
      [
        student.blackbaud_id,
        student.student_id,
        student.last_name,
        student.first_name,
        export_grade_level(student.grade),
        "Active",
        "Elementary Extended Care",
        record.total_cents / 100.0,
        "#{month_name} Extended Care billing"
      ]
    end

    send_data excel_xlsx([ EXPORT_HEADERS, *rows ]),
      filename: "#{month_name.downcase}-extended-care-billing.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
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

    def export_grade_level(grade)
      return "Kindergarten" if grade == Student::KINDERGARTEN

      suffix = case grade % 100
      when 11..13 then "th"
      else
        { 1 => "st", 2 => "nd", 3 => "rd" }[grade % 10] || "th"
      end
      "#{grade}#{suffix}"
    end

    def excel_xlsx(rows)
      column_count = rows.map(&:length).max || 0
      column_widths = (0...column_count).map do |column_index|
        content_width = rows.map { |row| row[column_index].to_s.length }.max || 0
        [ content_width + 2, 10 ].max.clamp(1, 255)
      end
      columns_xml = column_widths.each_with_index.map do |width, index|
        %(<col min="#{index + 1}" max="#{index + 1}" width="#{width}" customWidth="1"/>)
      end.join

      sheet_rows = rows.each_with_index.map do |row, row_index|
        cells = row.each_with_index.map do |value, column_index|
          reference = "#{excel_column_name(column_index + 1)}#{row_index + 1}"
          if value.is_a?(Numeric)
            %(<c r="#{reference}"><v>#{value}</v></c>)
          else
            content = xml_escape(value.to_s)
            %(<c r="#{reference}" t="inlineStr"><is><t xml:space="preserve">#{content}</t></is></c>)
          end
        end.join
        "<row r=\"#{row_index + 1}\">#{cells}</row>"
      end.join

      parts = {
        "[Content_Types].xml" => <<~XML,
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
            <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          </Types>
        XML
        "_rels/.rels" => <<~XML,
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
          </Relationships>
        XML
        "xl/workbook.xml" => <<~XML,
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <sheets><sheet name="Billing" sheetId="1" r:id="rId1"/></sheets>
          </workbook>
        XML
        "xl/_rels/workbook.xml.rels" => <<~XML,
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          </Relationships>
        XML
        "xl/worksheets/sheet1.xml" => <<~XML
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <cols>#{columns_xml}</cols>
            <sheetData>#{sheet_rows}</sheetData>
          </worksheet>
        XML
      }

      buffer = Zip::OutputStream.write_buffer do |zip|
        parts.each do |path, content|
          zip.put_next_entry(path)
          zip.write(content)
        end
      end
      buffer.string
    end

    def excel_column_name(number)
      name = +""
      while number.positive?
        number, remainder = (number - 1).divmod(26)
        name.prepend((65 + remainder).chr)
      end
      name
    end

    def xml_escape(value)
      value = value.gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/, "")
      ERB::Util.html_escape(value)
    end
end
