class BillingRecord < ApplicationRecord
  belongs_to :student, inverse_of: :billing_records

  validates :day, presence: true
  validates :student_id, uniqueness: { scope: :day }

  def total
    total_cents / 100.0
  end

  def self.recalculate!(student:, day:)
    visits = Attendance.on(day).where(student_id: student.id).order(:checkin).to_a
    amounts = calculate_amounts(visits.select { |visit| visit.checkout.present? }, day: day, student: student)
    # if student.staff? || student.prepaid_am? || student.prepaid_pm?
    #   amounts = { am_cents: 0, pm_cents: 0, late_fee_cents: 0, total_cents: 0 }
    # end
    amounts[:notes] = visit_summary(visits)
    record = find_or_initialize_by(student: student, day: day)
    record.assign_attributes(amounts)
    record.save!
    record
  end

  def self.calculate_amounts(visits, day:, student:)
    am_visits = visits.select { |visit| visit.checkin.in_time_zone.hour < 12 }
    pm_visits = visits.select { |visit| visit.checkin.in_time_zone.hour >= 12 }

    am_cents = am_visits.empty? || student.staff? || student.prepaid_am? ? 0 : 500

    pm_seconds = pm_visits.sum { |visit| visit.checkout - visit.checkin }
    pm_minutes = (pm_seconds.ceil + 59) / 60
    extra_minutes = [ pm_minutes - 60, 0 ].max
    extra_half_hour_blocks = (extra_minutes + 29) / 30
    pm_cents = pm_minutes.positive? ? 1_000 + extra_half_hour_blocks * 500 : 0
    pm_cents = student.staff? || student.prepaid_pm? ? 0 : pm_cents
    
    late_fee_cents = 0
    final_checkout = pm_visits.map(&:checkout).max
    if final_checkout
      schedule = ExtendedCareSchedule.for_day(day)
      scheduled_end = Time.zone.local(day.year, day.month, day.day, schedule.end_time.hour, schedule.end_time.min)
      late_start = scheduled_end
      late_minutes = ((final_checkout - late_start) / 60.0).ceil
      late_fee_cents = case late_minutes
      when 1..10 then 2_500
      when 11..20 then 5_000
      when 21..30 then 7_500
      when 31.. then 10_000
      else 0
      end
    end

    pm_total = [ pm_cents + late_fee_cents, 12_500 ].min
    { am_cents: am_cents, pm_cents: pm_cents, late_fee_cents: late_fee_cents,
      total_cents: [ am_cents + pm_total, 13_000 ].min }
  end

  def self.visit_summary(visits)
    visits.map do |visit|
      checked_in = visit.checkin.in_time_zone.strftime("%-I:%M%P").gsub("pm","p")
      checked_out = visit.checkout&.in_time_zone&.strftime("%-I:%M%P").gsub("pm","p") || "open"
      "#{checked_in}–#{checked_out}"
    end.join("; ")
  end
end
