class ExtendedCareSchedule < ApplicationRecord
  validates :start_time, :end_time, presence: true
  validate :end_after_start

  def self.for_day(day)
    find_by(day: day) || find_by(day: nil) || default_schedule
  end

  def self.default_schedule
    new(start_time: Time.zone.parse("15:00"), end_time: Time.zone.parse("17:30"))
  end

  private

  def end_after_start
    errors.add(:end_time, "must be after the start time") if start_time && end_time && end_time <= start_time
  end
end
