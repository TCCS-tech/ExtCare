class Attendance < ApplicationRecord
  self.table_name = "attendance"

  belongs_to :student, inverse_of: :attendances
  belongs_to :recorded_by, class_name: "User", foreign_key: :checkin_by

  validates :day, :checkin, presence: true

  # Billing is a stored snapshot of the visit list, so it has to be re-derived
  # whenever that list changes shape. The AM/PM split and the PM minute count
  # both read `checkin`, and re-dating a visit moves a charge between two days,
  # so those edits count too, not just the checkout that used to be the only
  # trigger here.
  BILLING_ATTRIBUTES = %i[day checkin checkout].freeze

  after_update_commit :recalculate_billing, if: :saved_change_to_billing_attribute?
  after_destroy_commit :recalculate_billing

  scope :open, -> { where(checkout: nil) }
  scope :on, ->(day) { where(day: day) }

  def open?
    checkout.nil?
  end

  def self.check_in(student:, by:, day:, time: nil)
    if day < Date.current && time.present? && !valid_checkin_time?(time)
      record = new(student: student, day: day, checkin_by: by.id)
      record.errors.add(:base, "Choose a valid check-in time for this past date.")
      return record
    end

    record = new(student: student, day: day, checkin: stamp(day, time: time), checkin_by: by.id)

    if student.hidden?
      record.errors.add(:base, "That student is not on the active list.")
      return record
    end

    if student.attendances.open.exists?
      record.errors.add(:base, "Already checked in. Check out first.")
      return record
    end

    record.save!
    record
  rescue ActiveRecord::RecordNotUnique
    record.errors.add(:base, "Already checked in. Check out first.")
    record
  rescue ActiveRecord::StatementInvalid => error
    raise unless open_visit_violation?(error)

    record.errors.add(:base, "Already checked in. Check out first.")
    record
  end

  def check_out(time: nil)
    stamped = if day == Date.current
      Time.current
    else
      Attendance.stamp(day, time: time)
    end
    stamped = checkin + 1.minute if day == Date.current && stamped <= checkin
    return false if stamped <= checkin

    update!(checkout: stamped)
  end

  def self.stamp(day, time: nil)
    now = Time.current
    return now if day == now.to_date

    time = now.strftime("%H:%M") if time.blank?
    hour, minute = time.to_s.split(":", 3).first(2).map { |part| Integer(part, 10) }
    Time.zone.local(day.year, day.month, day.day, hour, minute)
  end

  def self.valid_checkin_time?(time)
    time.to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d\z/)
  end
  private_class_method :valid_checkin_time?

  def self.open_visit_violation?(error)
    cause = error.cause
    cause.is_a?(PG::UniqueViolation) || cause.is_a?(PG::ExclusionViolation)
  end
  private_class_method :open_visit_violation?

  private

  def saved_change_to_billing_attribute?
    BILLING_ATTRIBUTES.any? { |name| saved_change_to_attribute?(name) }
  end

  # The days this change can move a charge on or off: the record's own day, plus
  # the day it used to be when an admin re-dates a visit.
  def billing_days
    return [ day ] unless saved_change_to_day?

    [ attribute_before_last_save("day"), day ].uniq
  end

  def recalculate_billing
    billing_days.each do |billing_day|
      BillingRecord.recalculate!(student: student, day: billing_day)
    end
  end
end
