class Student < ApplicationRecord
  # Aftercare takes Kindergarten through 6th grade. Kindergarten is stored as
  # grade 0 and shown as "K" everywhere in the UI.
  KINDERGARTEN = 0
  GRADES = (KINDERGARTEN..6).freeze

  has_many :attendances, inverse_of: :student

  normalizes :first_name, :last_name, with: ->(name) { name.to_s.strip.gsub(/\s+/, " ") }
  normalizes :blackbaud_id, with: ->(value) { value.to_s.strip.presence }

  validates :first_name, :last_name, presence: true
  validates :grade, inclusion: { in: GRADES }
  validates :blackbaud_id, uniqueness: true, allow_nil: true
  validates :first_name, uniqueness: { scope: :last_name, message: "and last name are already used by another student" }

  scope :visible, -> { where(hidden: false) }
  # Grade filters arrive as URL strings: "0" and "K" are Kindergarten, and
  # anything unrecognised ("all", "", junk) leaves the roster unfiltered.
  scope :in_grade, ->(grade) {
    number = grade_number(grade)
    number ? where(students: { grade: number }) : all
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

  # Grade levels in display order, as [label, value] pairs, shared by the
  # grade filter buttons and the admin grade picker.
  def self.grade_options
    GRADES.map { |grade| [grade_label(grade), grade] }
  end

  # The number a grade filter refers to, or nil when it names no level.
  def self.grade_number(grade)
    case grade.to_s.strip.downcase
    when "k", "0" then KINDERGARTEN
    when /\A[1-6]\z/ then grade.to_i
    end
  end

  def self.grade_label(grade)
    grade_number(grade) == KINDERGARTEN ? "K" : grade.to_s
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def grade_label
    self.class.grade_label(grade)
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
