require "digest"
require "fileutils"
require "tmpdir"
require "zip"

class SchoolYearRollover < ApplicationRecord
  class NotReady < StandardError; end
  class StaleBackup < StandardError; end

  TABLES = [ Student, Attendance, BillingRecord ].freeze
  BATCH_SIZE = 500

  belongs_to :user
  enum :status, %w[pending generating ready failed completed].index_by(&:itself)
  before_validation -> { self.backup_key ||= SecureRandom.uuid }, on: :create

  def self.backup_directory
    Pathname.new(ENV.fetch("SCHOOL_YEAR_BACKUP_DIRECTORY") { Rails.root.join("storage", "school_year_backups").to_s })
  end

  def backup_path
    self.class.backup_directory.join("#{backup_key}.zip")
  end

  def backup_filename
    "school-year-backup-#{created_at.strftime('%Y-%m-%d')}-#{id}.zip"
  end

  def waiting?
    pending? || generating?
  end

  def interrupted?
    waiting? && updated_at < 2.hours.ago
  end

  def generate_backup
    with_lock do
      return unless pending?
      update!(status: :generating, error_message: nil)
    end

    FileUtils.mkdir_p(self.class.backup_directory, mode: 0o700)
    Dir.mktmpdir("rollover-", self.class.backup_directory) do |directory|
      fingerprints = {}
      # One snapshot across all three tables, even while staff continue working.
      self.class.transaction(isolation: :repeatable_read) do
        TABLES.each do |model|
          writer = SchoolYearRollover::Workbook.new(File.join(directory, "#{model.table_name}.xlsx"), model.column_names)
          fingerprints[model.table_name] = fingerprint(model) { |row| writer.write(row) }
          writer.close
        ensure
          writer&.close
        end
      end
      archive = File.join(directory, "backup.zip")
      Zip::OutputStream.open(archive) do |zip|
        TABLES.each do |model|
          zip.put_next_entry("#{model.table_name}.xlsx")
          File.open(File.join(directory, "#{model.table_name}.xlsx"), "rb") do |file|
            while (chunk = file.read(64 * 1024))
              zip.write(chunk)
            end
          end
        end
      end
      File.chmod(0o600, archive)
      File.rename(archive, backup_path)
      update!(status: :ready, fingerprints: fingerprints)
    end
  rescue StandardError => error
    update!(status: :failed, error_message: "The backup could not be created. Please start again.")
    Rails.logger.error("School year backup #{id} failed: #{error.class}")
    raise
  end

  def record_download!
    with_lock do
      raise NotReady, "Create a backup before downloading it." unless ready? && backup_path.file?
      update!(downloaded_at: Time.current)
    end
  end

  def complete!(confirmation:)
    with_lock do
      return if completed?
      unless ready? && downloaded_at? && backup_path.file? && confirmation == "I UNDERSTAND"
        raise NotReady, "Download the backup and type I UNDERSTAND before continuing."
      end

      self.class.connection.execute("SET LOCAL lock_timeout = '10s'")
      tables = TABLES.map { |model| self.class.connection.quote_table_name(model.table_name) }.join(", ")
      # Block concurrent writes between the freshness check and the atomic reset.
      self.class.connection.execute("LOCK TABLE #{tables} IN ACCESS EXCLUSIVE MODE")
      current = TABLES.to_h { |model| [ model.table_name, fingerprint(model) ] }
      raise StaleBackup, "Data changed after this backup. Start again and download a new backup." unless current == fingerprints

      self.class.connection.execute("TRUNCATE TABLE #{tables} RESTART IDENTITY")
      update!(status: :completed, completed_at: Time.current)
    end
  end

  private
    def fingerprint(model)
      digest = Digest::SHA256.new
      columns = model.column_names
      digest << columns.to_json << "\n"
      # Pluck only one batch at a time; never instantiate the full record set.
      model.uncached do
        model.unscoped.in_batches(of: BATCH_SIZE) do |batch|
          batch.order(:id).pluck(*columns).each do |values|
            row = values.map { |value| backup_value(value) }
            digest << row.to_json << "\n"
            yield row if block_given?
          end
        end
      end
      digest.hexdigest
    end

    def backup_value(value)
      case value
      when Time, ActiveSupport::TimeWithZone then value.iso8601(6)
      when Date then value.iso8601
      when Array, Hash then value.to_json
      when nil then nil
      else value.to_s
      end
    end
end
