class Student < ApplicationRecord
  has_many :attendances, inverse_of: :student

  normalizes :first_name, :last_name, with: ->(name) { name.to_s.strip.gsub(/\s+/, " ") }
  normalizes :blackbaud_id, with: ->(value) { value.to_s.strip.presence }

  validates :first_name, :last_name, presence: true
  validates :grade, inclusion: { in: 1..6 }
  validates :blackbaud_id, uniqueness: true, allow_nil: true
  validates :first_name, uniqueness: { scope: :last_name, message: "and last name are already used by another student" }

  scope :visible, -> { where(hidden: false) }
  scope :in_grade, ->(grade) {
    number = grade.to_i
    grade.to_s == number.to_s && (1..6).cover?(number) ? where(students: { grade: number }) : all
  }
  scope :named, ->(query) {
    term = query.to_s.strip
    next all if term.blank?

    like = "%#{sanitize_sql_like(term)}%"
    where(
      "students.first_name ILIKE :q OR students.last_name ILIKE :q OR (students.first_name || ' ' || students.last_name) ILIKE :q",
      q: like
    )
  }
  scope :ordered_by_name, -> {
    order(Arel.sql("lower(students.first_name), lower(students.last_name), students.id"))
  }

  def full_name
    "#{first_name} #{last_name}"
  end

  def guardian_list
    guardians.to_a.join(", ")
  end

  def guardian_list=(value)
    self.guardians = value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def hide!
    update!(hidden: true)
  end

  def restore!
    update!(hidden: false)
  end
end
