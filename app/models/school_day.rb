class SchoolDay
  # Only up to today is viewable: a future day has no attendance to manage, so
  # a future day reads as today. This also keeps a check-in from being stamped
  # against a day that has not happened.
  def self.parse(value)
    return Date.current if value.blank?

    [ Date.iso8601(value.to_s), Date.current ].min
  rescue Date::Error
    Date.current
  end
end
