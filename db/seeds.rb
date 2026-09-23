admin = User.find_or_initialize_by(email: "admin@example.com")
admin.password = "password"
admin.role = :admin
admin.save!

staff = User.find_or_initialize_by(email: "staff@example.com")
staff.password = "password"
staff.role = :user
staff.save!

roster = [
  [ "Amara", "Bell", 0, "Nia Bell", nil ],
  [ "Theo", "Marsh", 0, "Dana Marsh", nil ],
  [ "Zoe", "Sandoval", 0, "Marcia Sandoval", nil ],
  [ "Mia", "Alvarez", 1, "Ana Alvarez, Luis Alvarez", "BB1001" ],
  [ "Noah", "Bennett", 1, "Chris Bennett", nil ],
  [ "Ava", "Chen", 1, "Mei Chen", nil ],
  [ "Liam", "Diaz", 2, "Rosa Diaz", "BB1004" ],
  [ "Olivia", "Flores", 2, "Juan Flores", nil ],
  [ "Ethan", "Garcia", 2, "Sofia Garcia", nil ],
  [ "Sophia", "Hughes", 3, "Jordan Hughes", nil ],
  [ "Lucas", "Ibrahim", 3, "Noor Ibrahim", nil ],
  [ "Emma", "Johnson", 3, "Alex Johnson", nil ],
  [ "Mason", "Kim", 4, "Hana Kim", "BB1010" ],
  [ "Isabella", "Lopez", 4, "Maria Lopez", nil ],
  [ "Logan", "Martinez", 4, "Diego Martinez", nil ],
  [ "Amelia", "Nguyen", 5, "Lan Nguyen", nil ],
  [ "Elijah", "Ortiz", 5, "Camila Ortiz", nil ],
  [ "Harper", "Patel", 5, "Raj Patel", nil ],
  [ "James", "Quinn", 6, "Erin Quinn", nil ],
  [ "Charlotte", "Rivera", 6, "Luis Rivera", nil ],
  [ "Benjamin", "Scott", 6, "Taylor Scott", nil ]
]

students = roster.map do |first_name, last_name, grade, guardians, blackbaud_id|
  student = Student.find_or_initialize_by(first_name: first_name, last_name: last_name)
  next student unless student.new_record?

  student.grade = grade
  student.guardian_list = guardians
  student.blackbaud_id = blackbaud_id
  student.save!
  student
end

hidden = Student.find_or_initialize_by(first_name: "Nora", last_name: "Vance")
if hidden.new_record?
  hidden.grade = 1
  hidden.guardian_list = "Riley Vance"
  hidden.hidden = true
  hidden.save!
end

if Attendance.none?
  yesterday = Date.current - 1
  today = Date.current

  students.each_with_index do |student, index|
    next unless (index % 3).zero?

    Attendance.create!(
      student: student,
      day: yesterday,
      checkin: Time.zone.local(yesterday.year, yesterday.month, yesterday.day, 15, 0),
      checkout: Time.zone.local(yesterday.year, yesterday.month, yesterday.day, 17, 0),
      checkin_by: staff.id,
      checkout_by: staff.email
    )
  end

  completed = students.find { |student| student.first_name == "Sophia" }
  Attendance.create!(
    student: completed,
    day: today,
    checkin: Time.current - 2.hours,
    checkout: Time.current - 90.minutes,
    checkin_by: admin.id,
    checkout_by: admin.email
  )

  students.first(4).each_with_index do |student, index|
    Attendance.create!(
      student: student,
      day: today,
      checkin: Time.current - (10 + index * 5).minutes,
      checkin_by: staff.id
    )
  end
end

puts "Admin login: admin@example.com / password"
puts "Staff login: staff@example.com / password"
