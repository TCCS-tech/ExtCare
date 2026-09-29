# Disk-backed XLSX writer. Inline strings avoid a growing shared-string table
# and preserve identifiers, timestamps, and text beginning with '=' exactly.
class SchoolYearRollover::Workbook
  MAX_ROWS = 1_048_576
  NAMESPACE = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
  RELATIONSHIPS = "http://schemas.openxmlformats.org/package/2006/relationships"
  OFFICE_RELATIONSHIPS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

  def initialize(path, headers)
    @zip = Zip::OutputStream.new(path)
    @headers = headers
    @sheets = 0
    start_sheet
  end

  def write(values)
    start_sheet if @row == MAX_ROWS
    @row += 1
    @zip.write(%(<row r="#{@row}">))
    values.each_with_index do |value, index|
      next if value.nil?
      raise ArgumentError, "Cell exceeds Excel's text limit" if value.length > 32_767
      # Encode XML-forbidden control characters using OOXML's escape syntax,
      # first protecting literal strings that already resemble such escapes.
      text = value.gsub(/_x[0-9a-fA-F]{4}_/) { |match| "_x005F_#{match.delete_prefix('_')}" }
        .gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\uFFFE\uFFFF]/) { |char| "_x%04X_" % char.ord }
      @zip.write(%(<c r="#{column_name(index + 1)}#{@row}" t="inlineStr"><is><t xml:space="preserve">#{ERB::Util.html_escape(text)}</t></is></c>))
    end
    @zip.write("</row>")
  end

  def close
    return if @closed
    @closed = true
    @zip.write("</sheetData></worksheet>")
    parts = {
      "[Content_Types].xml" => %(<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>#{(1..@sheets).map { |n| %(<Override PartName="/xl/worksheets/sheet#{n}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>) }.join}</Types>),
      "_rels/.rels" => %(<Relationships xmlns="#{RELATIONSHIPS}"><Relationship Id="rId1" Type="#{OFFICE_RELATIONSHIPS}/officeDocument" Target="xl/workbook.xml"/></Relationships>),
      "xl/workbook.xml" => %(<workbook xmlns="#{NAMESPACE}" xmlns:r="#{OFFICE_RELATIONSHIPS}"><sheets>#{(1..@sheets).map { |n| %(<sheet name="Data #{n}" sheetId="#{n}" r:id="rId#{n}"/>) }.join}</sheets></workbook>),
      "xl/_rels/workbook.xml.rels" => %(<Relationships xmlns="#{RELATIONSHIPS}">#{(1..@sheets).map { |n| %(<Relationship Id="rId#{n}" Type="#{OFFICE_RELATIONSHIPS}/worksheet" Target="worksheets/sheet#{n}.xml"/>) }.join}</Relationships>)
    }
    parts.each do |name, xml|
      @zip.put_next_entry(name)
      @zip.write(xml)
    end
    @zip.close
  end

  private
    def start_sheet
      @zip.write("</sheetData></worksheet>") if @sheets.positive?
      @sheets += 1
      @row = 0
      @zip.put_next_entry("xl/worksheets/sheet#{@sheets}.xml")
      @zip.write(%(<worksheet xmlns="#{NAMESPACE}"><sheetData>))
      write(@headers)
    end

    def column_name(number)
      name = +""
      while number.positive?
        number, remainder = (number - 1).divmod(26)
        name.prepend((65 + remainder).chr)
      end
      name
    end
end
