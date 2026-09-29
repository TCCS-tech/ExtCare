require "test_helper"
require "rexml/document"

class SchoolYearRolloverTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Real transactions are needed for the repeatable-read snapshot and TRUNCATE.
  self.use_transactional_tests = false

  setup do
    BillingRecord.delete_all
    Attendance.delete_all
    Student.delete_all
    SchoolYearRollover.delete_all
    @student = Student.create!(first_name: "=SUM(1,2)", last_name: "A & <B>", grade: 1,
      blackbaud_id: "001234567890123456789", student_id: "001", hidden: true,
      guardians: [ "A", "B" ], alert: "literal _x0001_\ncontrol\u0001")
    @visit = Attendance.create!(student: @student, recorded_by: users(:admin),
      day: Date.current, checkin: Time.current, pickup_notes: "Every column")
    @billing = BillingRecord.create!(student: @student, day: Date.current, total_cents: 1234, notes: "Historical")
    @rollover = users(:admin).school_year_rollovers.create!
  end

  teardown do
    FileUtils.rm_f(@rollover.backup_path)
    BillingRecord.delete_all
    Attendance.delete_all
    Student.delete_all
    SchoolYearRollover.delete_all
  end

  test "backup includes all columns and rows as three valid XLSX files with batches" do
    (SchoolYearRollover::BATCH_SIZE + 1).times do |n|
      Student.create!(first_name: "Batch", last_name: n.to_s, grade: 0, blackbaud_id: n.to_s, student_id: n.to_s)
    end
    @rollover.generate_backup
    assert @rollover.reload.ready?
    assert_equal 3, @rollover.fingerprints.size
    Zip::File.open(@rollover.backup_path) do |archive|
      assert_equal %w[attendance.xlsx billing_records.xlsx students.xlsx], archive.entries.map(&:name).sort
      SchoolYearRollover::TABLES.each do |model|
        Tempfile.create([ "check", ".xlsx" ]) do |file|
          file.binmode
          file.write(archive.read("#{model.table_name}.xlsx"))
          file.flush
          Zip::File.open(file.path) do |workbook|
            workbook.entries.each { |entry| REXML::Document.new(workbook.read(entry.name)) }
            sheet = REXML::Document.new(workbook.read("xl/worksheets/sheet1.xml"))
            rows = REXML::XPath.match(sheet, "//s:row", { "s" => SchoolYearRollover::Workbook::NAMESPACE })
            assert_equal model.count + 1, rows.length
            assert_equal model.column_names, rows.first.get_elements("c/is/t").map(&:text)
            if model == Student
              text = workbook.read("xl/worksheets/sheet1.xml")
              assert_includes text, "001234567890123456789"
              assert_includes text, "=SUM(1,2)"
              assert_includes text, "_x005F_x0001_"
              assert_includes text, "control_x0001_"
              assert_not_includes text, "<f>"
            end
          end
        end
      end
    end
  end

  test "complete wizard truncates tables and restarts all identities" do
    perform_enqueued_jobs(only: SchoolYearBackupJob) { SchoolYearBackupJob.perform_later(@rollover) }
    @rollover.record_download!
    @rollover.complete!(confirmation: "I UNDERSTAND")
    assert @rollover.reload.completed?
    assert @rollover.completed_at
    assert SchoolYearRollover::TABLES.all? { |model| model.count.zero? }
    student = Student.create!(first_name: "New", last_name: "Year", grade: 0, blackbaud_id: "new", student_id: "new")
    assert_equal 1, student.id
    visit = Attendance.create!(student: student, recorded_by: users(:admin), day: Date.current, checkin: Time.current)
    assert_equal 1, visit.id
    billing = BillingRecord.create!(student: student, day: Date.current)
    assert_equal 1, billing.id
    @rollover.complete!(confirmation: "I UNDERSTAND")
    assert Student.exists?(student.id), "A repeated request must not delete the new year's data"
    assert User.exists?(users(:admin).id)
  end

  test "insert update and delete after backup each prevent any reset" do
    @rollover.generate_backup
    @rollover.record_download!
    @student.update!(first_name: "Changed")
    assert_raises(SchoolYearRollover::StaleBackup) { @rollover.complete!(confirmation: "I UNDERSTAND") }
    assert Attendance.exists?(@visit.id)
    @student.update!(first_name: "=SUM(1,2)")
    @rollover.update!(status: :pending)
    @rollover.generate_backup
    @billing.delete
    assert_raises(SchoolYearRollover::StaleBackup) { @rollover.complete!(confirmation: "I UNDERSTAND") }
    assert Student.exists?(@student.id)
    @rollover.update!(status: :pending)
    @rollover.generate_backup
    Student.create!(first_name: "Added", last_name: "Later", grade: 0, blackbaud_id: "added", student_id: "added")
    assert_raises(SchoolYearRollover::StaleBackup) { @rollover.complete!(confirmation: "I UNDERSTAND") }
    assert_equal 2, Student.count
    assert @rollover.reload.ready?
  end

  test "failed export never permits deletion and reports failure" do
    @student.update!(alert: "x" * 32_768)
    assert_raises(ArgumentError) { @rollover.generate_backup }
    assert @rollover.reload.failed?
    assert_not @rollover.backup_path.exist?
    assert_raises(SchoolYearRollover::NotReady) { @rollover.complete!(confirmation: "I UNDERSTAND") }
    assert Student.exists?(@student.id)
  end
end
