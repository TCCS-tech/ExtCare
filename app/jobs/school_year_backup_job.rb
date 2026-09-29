class SchoolYearBackupJob < ApplicationJob
  self.enqueue_after_transaction_commit = true

  def perform(rollover)
    rollover.generate_backup
  end
end
