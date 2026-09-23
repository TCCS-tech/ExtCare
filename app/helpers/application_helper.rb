module ApplicationHelper
  def clock(time)
    l(time, format: :check)
  end

  # Word for the current part of the day; the morning ends at noon. Uses
  # Time.zone (Pacific), not the server's or the browser's clock.
  def part_of_day(time = Time.zone.now)
    time.hour < 12 ? "morning" : "afternoon"
  end

  def nav_link_class(name)
    "nav-link#{" active" if controller_name == name}"
  end
end
