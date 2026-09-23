admin = User.find_or_initialize_by(email: "admin@example.com")
admin.password = "password"
admin.role = :admin
admin.save!

staff = User.find_or_initialize_by(email: "staff@example.com")
staff.password = "password"
staff.role = :user
staff.save!

puts "Admin login: admin@example.com / password"
puts "Staff login: staff@example.com / password"
