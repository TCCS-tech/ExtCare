class Attendance < ApplicationRecord
  self.table_name = "attendance"

  belongs_to :student, inverse_of: :attendances
  belongs_to :recorded_by, class_name: "User", foreign_key: :checkin_by

  validates :day, :checkin, presence: true

  scope :open, -> { where(checkout: nil) }
  scope :on, ->(day) { where(day: day) }

  def open?
    checkout.nil?
  end

  def self.check_in(student:, by:, day:)
    record = new(student: student, day: day, checkin: stamp(day), checkin_by: by.id)

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

  def check_out
    stamped = Time.current
    stamped = checkin + 1.minute if stamped <= checkin
    update!(checkout: stamped)
  end

  def self.stamp(day)
    now = Time.current
    return now if day == now.to_date

    Time.zone.local(day.year, day.month, day.day, now.hour, now.min, now.sec)
  end

  def self.open_visit_violation?(error)
    cause = error.cause
    cause.is_a?(PG::UniqueViolation) || cause.is_a?(PG::ExclusionViolation)
  end
  private_class_method :open_visit_violation?
end
