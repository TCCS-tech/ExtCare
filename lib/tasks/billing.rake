namespace :billing do
  desc "Recalculate every billing record from attendance"
  task recalculate_all: :environment do
    pairs = (Attendance.distinct.pluck(:student_id, :day) + BillingRecord.pluck(:student_id, :day)).uniq
    recalculated = 0

    pairs.each_slice(500) do |batch|
      students = Student.where(id: batch.map(&:first).uniq).index_by(&:id)

      batch.each do |student_id, day|
        student = students[student_id]
        next unless student

        BillingRecord.recalculate!(student: student, day: day)
        recalculated += 1
      end
    end

    puts "Recalculated billing for #{recalculated} student-days."
  end
end
