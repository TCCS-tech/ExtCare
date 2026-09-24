class Student < ApplicationRecord
  # Aftercare takes Kindergarten through 6th grade. Kindergarten is stored as
  # grade 0 and shown as "K" everywhere in the UI.
  KINDERGARTEN = 0
  GRADES = (KINDERGARTEN..6).freeze
  # Program flags, in the order they are shown. Kept here so a flag reads the
  # same on the check-in and check-out rows and in the admin roster.
  FLAGS = [ [ "staff", "Staff" ], [ "prepaid_am", "Prepaid AM" ], [ "prepaid_pm", "Prepaid PM" ] ].freeze

  has_many :attendances, inverse_of: :student

  normalizes :first_name, :last_name, with: ->(name) { name.to_s.strip.gsub(/\s+/, " ") }
  normalizes :blackbaud_id, with: ->(value) { value.to_s.strip.presence }
  normalizes :student_id, with: ->(value) { value.to_s.strip.presence }

  validates :first_name, :last_name, :blackbaud_id, :student_id, presence: true
  validates :grade, inclusion: { in: GRADES }
  # There could be a duplicate student_id with 2 different blackbaud_ids, for split families billing
  validates :blackbaud_id, uniqueness: false, allow_nil: false
  validates :student_id, uniqueness: false, allow_nil: false

  scope :visible, -> { where(hidden: false) }
  # Grade filters arrive as URL strings: "0" and "K" are Kindergarten, and
  # anything unrecognised ("all", "", junk) leaves the roster unfiltered.
  scope :in_grade, ->(grade) {
    number = grade_number(grade)
    number ? where(students: { grade: number }) : all
  }

  scope :named, ->(query) {
    terms = query.to_s.split
    next all if terms.empty?

    t = arel_table

    filters = terms.flat_map { |term|
      pattern = "%#{sanitize_sql_like(term)}%"
      [
        t[:first_name].matches(pattern),
        t[:last_name].matches(pattern)
      ]
    }
    relation = where(filters.reduce(:or))

    first, last = terms.first, terms.last
    first_prefix = "#{sanitize_sql_like(first)}%"
    last_prefix  = "#{sanitize_sql_like(last)}%"
    first_any    = "%#{sanitize_sql_like(first)}%"
    last_any     = "%#{sanitize_sql_like(last)}%"

    score_sql =
      if terms.length >= 2
        sanitize_sql_array([
          <<~SQL.squish,
            CASE
              WHEN first_name ILIKE ? AND last_name ILIKE ? THEN 500
              WHEN first_name ILIKE ? AND last_name ILIKE ? THEN 400
              WHEN first_name ILIKE ? OR  last_name ILIKE ? THEN 300
              WHEN first_name ILIKE ? OR  last_name ILIKE ? THEN 200
              ELSE 0
            END
          SQL
          first_prefix, last_prefix,   # 500
          first_any,    last_any,      # 400
          first_prefix, last_prefix,   # 300
          first_any,    last_any       # 200
        ])
      else
        sanitize_sql_array([
          <<~SQL.squish,
            CASE
              WHEN first_name ILIKE ? OR last_name ILIKE ? THEN 300
              WHEN first_name ILIKE ? OR last_name ILIKE ? THEN 200
              ELSE 0
            END
          SQL
          first_prefix, first_prefix,  # 300
          first_any,    first_any      # 200
        ])
      end

    # optional: +10 per term hit, still bound
    hit_bonus = terms.map { |term|
      p = "%#{sanitize_sql_like(term)}%"
      sanitize_sql_array(
        ["(CASE WHEN first_name ILIKE ? OR last_name ILIKE ? THEN 10 ELSE 0 END)", p, p]
      )
    }.join(" + ")

    relation.order(Arel.sql("(#{score_sql} + #{hit_bonus}) DESC"))
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

  # Labels of the flags this student has, in FLAGS order.
  def flag_labels
    FLAGS.filter_map { |attribute, label| label if public_send(attribute) }
  end

  def hide!
    update!(hidden: true)
  end

  def restore!
    update!(hidden: false)
  end
end
