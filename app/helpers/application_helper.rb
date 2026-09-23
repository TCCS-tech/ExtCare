module ApplicationHelper
  def clock(time)
    l(time, format: :check)
  end

  def nav_link_class(name)
    "nav-link#{" active" if controller_name == name}"
  end
end
