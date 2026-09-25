class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", ENV.fetch("SMTP_USERNAME", "techhub@tccs.org"))
  layout "mailer"
end
