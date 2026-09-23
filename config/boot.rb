# Wall-clock times are Pacific. Set before Ruby caches the process zone.
ENV["TZ"] = "America/Los_Angeles"

libpq = "/opt/homebrew/opt/libpq/bin"
if File.directory?(libpq) && !ENV["PATH"].to_s.split(File::PATH_SEPARATOR).include?(libpq)
  ENV["PATH"] = "#{libpq}#{File::PATH_SEPARATOR}#{ENV["PATH"]}"
end

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
