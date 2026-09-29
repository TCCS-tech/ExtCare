require "set"

class Student::Import
  class InvalidFile < StandardError; end

  MAX_UPLOAD_SIZE = 20.megabytes
  IGNORED_COLUMNS = %w[id created_at updated_at].freeze
  BOOLEAN_COLUMNS = %w[staff prepaid_am prepaid_pm hidden].freeze
  ARRAY_COLUMNS = %w[guardians additional_adults].freeze

  attr_reader :created, :updated, :unchanged

  def initialize(upload)
    @upload = upload
    @created = @updated = @unchanged = 0
    @identifiers = Set.new
  end

  def save!
    unless @upload.respond_to?(:tempfile) && File.extname(@upload.original_filename.to_s).downcase == ".xlsx"
      raise InvalidFile, "Choose a students.xlsx file from a school year backup."
    end
    raise InvalidFile, "The file must be 20 MB or smaller." if @upload.size > MAX_UPLOAD_SIZE

    Student.transaction(requires_new: true) do
      # Serialize imports with student edits to avoid duplicate inserts or a
      # concurrent edit between a row's lookup and update. No other tables reset.
      Student.connection.execute("SET LOCAL lock_timeout = '10s'")
      Student.connection.execute("LOCK TABLE students IN SHARE ROW EXCLUSIVE MODE")
      Student.uncached do
        Student::Import::Workbook.new(@upload.tempfile.path).each_row do |sheet, number, values|
          import_row(values)
        rescue InvalidFile, ActiveRecord::RecordInvalid => error
          raise InvalidFile, "#{sheet}, row #{number}: #{error.message}"
        end
      end
    end
    self
  rescue Zip::Error, Nokogiri::XML::SyntaxError, EOFError, ArgumentError
    raise InvalidFile, "The file could not be read. Upload a valid students.xlsx from a school year backup."
  end

  private
    def import_row(values)
      attributes = values.except(*IGNORED_COLUMNS)
      attributes["grade"] = strict_grade(attributes["grade"])
      BOOLEAN_COLUMNS.each do |column|
        attributes[column] = case attributes[column]
        when "true", "1" then true
        when "false", "0" then false
        else raise InvalidFile, "#{column} must be true or false."
        end
      end
      ARRAY_COLUMNS.each { |column| attributes[column] = string_array(attributes[column], column) }
      # Normalize before lookup, using the same rules as Student forms.
      incoming = Student.new(attributes)
      unless incoming.valid?
        raise InvalidFile, incoming.errors.full_messages.to_sentence
      end
      identifiers = [ incoming.blackbaud_id, incoming.student_id ]
      unless @identifiers.add?(identifiers)
        raise InvalidFile, "This Blackbaud ID and student ID pair appears more than once in the file."
      end
      student = Student.find_or_initialize_by(blackbaud_id: incoming.blackbaud_id, student_id: incoming.student_id)
      student.assign_attributes(incoming.attributes.slice(*attributes.keys))
      if student.new_record?
        student.save!
        @created += 1
      elsif student.changed?
        student.save!
        @updated += 1
      else
        @unchanged += 1
      end
    end

    def strict_grade(value)
      raise InvalidFile, "grade must be a whole number from 0 through 6." unless value.to_s.match?(/\A[0-6]\z/)
      value.to_i
    end

    def string_array(value, column)
      array = JSON.parse(value.to_s)
      unless array.is_a?(Array) && array.all? { |item| item.is_a?(String) }
        raise InvalidFile, "#{column} must be a JSON array of names."
      end
      array
    rescue JSON::ParserError
      raise InvalidFile, "#{column} must be a JSON array of names."
    end
end
