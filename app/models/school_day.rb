class SchoolDay
  def self.parse(value)
    return Date.current if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error
    Date.current
  end
end
