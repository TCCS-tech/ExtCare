require "zip"
require "nokogiri"
require "tempfile"

# Streams worksheet rows and keeps shared strings on disk, so importing a
# backup does not retain the whole workbook or all student records in memory.
class Student::Import::Workbook
  NAMESPACE = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
  MAX_EXPANDED_SIZE = 256.megabytes
  MAX_ROW_SIZE = 1.megabyte
  MAX_ENTRIES = 1024

  def initialize(path)
    @path = path
    @bytes_read = 0
  end

  def each_row
    Zip::File.open(@path) do |zip|
      if zip.entries.size > MAX_ENTRIES || zip.entries.sum(&:size) > MAX_EXPANDED_SIZE || zip.entries.map(&:name).uniq.size != zip.entries.size
        raise Student::Import::InvalidFile, "The workbook is too large or contains duplicate files."
      end
      sheets = zip.entries.select { |entry| entry.name.match?(%r{\Axl/worksheets/sheet\d+\.xml\z}) }
        .sort_by { |entry| entry.name[/sheet(\d+)\.xml/, 1].to_i }
      raise Student::Import::InvalidFile, "The workbook contains no student worksheets." if sheets.empty?

      Tempfile.create("student-import-strings") do |strings|
        Tempfile.create("student-import-index") do |index|
          @strings, @index = strings.binmode, index.binmode
          read_shared_strings(zip) if zip.find_entry("xl/sharedStrings.xml")
          sheets.each do |sheet|
            headers = nil
            read_elements(zip, sheet.name, "row") do |row|
              number = row["r"]
              values = read_cells(row)
              next if values.compact.all?(&:blank?)
              unless headers
                headers = values
                if headers.uniq != headers || headers.sort != Student.column_names.sort
                  raise Student::Import::InvalidFile, "#{sheet.name}: column headers must match the students.xlsx backup exactly."
                end
                next
              end
              raise Student::Import::InvalidFile, "#{sheet.name}, row #{number}: too many columns." if values.size > headers.size
              yield File.basename(sheet.name, ".xml"), number, headers.zip(values).to_h
            end
            raise Student::Import::InvalidFile, "#{sheet.name}: student column headers are missing." unless headers
          end
        end
      end
    end
  end

  private
    def read_shared_strings(zip)
      read_elements(zip, "xl/sharedStrings.xml", "si") do |element|
        text = decode(text_content(element))
        @index.write([ @strings.pos, text.bytesize ].pack("Q>Q>"))
        @strings.write(text)
      end
      @strings.flush
      @index.flush
    end

    def read_elements(zip, path, name)
      zip.get_input_stream(path) do |input|
        # Check bytes as they are inflated, as well as checking ZIP metadata.
        stream = LimitedInput.new(input) do |size|
          @bytes_read += size
          raise Student::Import::InvalidFile, "The workbook expands to more than 256 MB." if @bytes_read > MAX_EXPANDED_SIZE
        end
        reader = Nokogiri::XML::Reader(stream, nil, nil, Nokogiri::XML::ParseOptions::NONET)
        reader.each do |node|
          if node.node_type == Nokogiri::XML::Reader::TYPE_DOCUMENT_TYPE
            raise Student::Import::InvalidFile, "XML document types are not allowed in imports."
          end
          next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT && node.local_name == name
          raise Student::Import::InvalidFile, "The workbook uses an unsupported spreadsheet format." unless node.namespace_uri == NAMESPACE
          xml = node.outer_xml
          raise Student::Import::InvalidFile, "A spreadsheet row or shared string is too large." if xml.bytesize > MAX_ROW_SIZE
          document = Nokogiri::XML(xml) { |config| config.strict.nonet }
          yield document.root
        end
      end
    end

    def read_cells(row)
      values = []
      columns = Set.new
      row.xpath("./s:c", "s" => NAMESPACE).each do |cell|
        reference = cell["r"].to_s
        unless reference.match?(/\A[A-Z]+[1-9]\d*\z/)
          raise Student::Import::InvalidFile, "A cell has an invalid column reference."
        end
        column = reference[/\A[A-Z]+/].each_byte.reduce(0) { |n, byte| n * 26 + byte - 64 } - 1
        if column >= Student.column_names.size
          raise Student::Import::InvalidFile, "The workbook has unexpected columns."
        end
        unless columns.add?(column)
          raise Student::Import::InvalidFile, "A column appears more than once in a row."
        end
        raise Student::Import::InvalidFile, "Formulas are not allowed. Use plain values." if cell.at_xpath("./s:f", "s" => NAMESPACE)
        value = cell.at_xpath("./s:v", "s" => NAMESPACE)&.text
        values[column] = case cell["t"]
        when "inlineStr"
          decode(text_content(cell.at_xpath("./s:is", "s" => NAMESPACE)))
        when "s"
          shared_string(value)
        when "b", "n", "str", nil
          decode(value) if value
        else
          raise Student::Import::InvalidFile, "A cell contains an unsupported value type."
        end
      end
      values
    end

    def text_content(element)
      raise Student::Import::InvalidFile, "A text cell is missing its value." unless element
      element.xpath("./s:t | ./s:r/s:t", "s" => NAMESPACE).map(&:text).join
    end

    def shared_string(value)
      raise Student::Import::InvalidFile, "A shared string reference is invalid." unless value.to_s.match?(/\A\d+\z/)
      @index.seek(value.to_i * 16)
      location = @index.read(16)
      raise Student::Import::InvalidFile, "A shared string reference is missing." unless location&.bytesize == 16
      offset, size = location.unpack("Q>Q>")
      @strings.seek(offset)
      @strings.read(size).force_encoding(Encoding::UTF_8)
    end

    def decode(value)
      # One pass preserves literal escapes protected with _x005F_ by the backup.
      text = value.gsub(/_x(D[89AB][0-9A-F]{2})__x(D[CDEF][0-9A-F]{2})_|_x([0-9A-F]{4})_/i) do
        match = Regexp.last_match
        codepoint = if match[3]
          match[3].to_i(16)
        else
          0x10000 + (match[1].to_i(16) - 0xD800) * 1024 + match[2].to_i(16) - 0xDC00
        end
        [ codepoint ].pack("U")
      end
      unless text.valid_encoding? && !text.include?("\u0000")
        raise Student::Import::InvalidFile, "A cell contains invalid text or a null character."
      end
      text
    end

    class LimitedInput
      def initialize(input, &count)
        @input, @count = input, count
      end

      def read(length)
        @input.read(length).tap { |bytes| @count.call(bytes.bytesize) if bytes }
      end
    end
end
