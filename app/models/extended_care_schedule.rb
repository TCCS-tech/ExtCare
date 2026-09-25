class ExtendedCareSchedule < ApplicationRecord
  WEEKDAYS = Date::DAYNAMES.map(&:downcase).freeze

  validates :start_time, :end_time, presence: true
  validates :day_of_week, inclusion: { in: WEEKDAYS }, allow_nil: true
  validate :date_and_weekday_are_mutually_exclusive
  validate :end_after_start
  before_validation :clear_blank_day_of_week

  def self.for_day(day)
    find_by(day: day) || find_by(day: nil, day_of_week: day.strftime("%A").downcase) ||
      find_by(day: nil, day_of_week: nil) || default_schedule
  end

  def self.default_schedule
    new(start_time: Time.zone.parse("15:00"), end_time: Time.zone.parse("17:30"))
  end

  private

  def clear_blank_day_of_week
    self.day_of_week = nil if day_of_week.blank?
  end

  def date_and_weekday_are_mutually_exclusive
    errors.add(:day, "and weekday cannot both be set") if day && day_of_week.present?
  end

  def end_after_start
    errors.add(:end_time, "must be after the start time") if start_time && end_time && end_time <= start_time
  end
end
