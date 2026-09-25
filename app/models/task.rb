class Task < ApplicationRecord
  belongs_to :created_by, class_name: "User"

  enum :status, { todo: "todo", done: "done" }, default: :todo, validate: true

  validates :title, presence: true
  validates :priority, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:priority, :created_at, :id) }

  before_validation :assign_priority, on: :create

  private
    def assign_priority
      self.priority = self.class.where(status: status || "todo").maximum(:priority).to_i + 1 if new_record?
    end
end
