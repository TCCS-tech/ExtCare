-- name: CountAdmins :one
SELECT count(*)::bigint AS count FROM admins;

-- name: CreateAdmin :one
INSERT INTO admins (email, password_hash)
VALUES ($1, $2)
RETURNING id, email, password_hash, created_at, updated_at;

-- name: GetAdminByEmail :one
SELECT id, email, password_hash, created_at, updated_at
FROM admins
WHERE email = $1;

-- name: GetAdminByID :one
SELECT id, email, password_hash, created_at, updated_at
FROM admins
WHERE id = $1;

-- name: ListAdmins :many
SELECT id, email, created_at
FROM admins
ORDER BY email;

-- name: DeleteAdmin :execrows
DELETE FROM admins
WHERE id = $1;

-- name: CreateSession :exec
INSERT INTO sessions (admin_id, token_hash, expires_at)
VALUES ($1, $2, $3);

-- name: GetSessionByTokenHash :one
SELECT s.admin_id, s.expires_at, a.email
FROM sessions s
JOIN admins a ON a.id = s.admin_id
WHERE s.token_hash = $1;

-- name: DeleteSessionByTokenHash :exec
DELETE FROM sessions
WHERE token_hash = $1;

-- name: DeleteExpiredSessions :exec
DELETE FROM sessions
WHERE expires_at < now();

-- name: CreateStudent :one
INSERT INTO students (student_id, name, grade)
VALUES ($1, $2, $3)
RETURNING id, student_id, name, grade, active, created_at, updated_at;

-- name: ListStudents :many
SELECT id, student_id, name, grade, active, created_at, updated_at
FROM students
ORDER BY active DESC, name ASC;

-- name: ListActiveStudents :many
SELECT id, student_id, name, grade, active, created_at, updated_at
FROM students
WHERE active
ORDER BY name ASC;

-- name: GetStudentByStudentID :one
SELECT id, student_id, name, grade, active, created_at, updated_at
FROM students
WHERE student_id = $1;

-- name: UpdateStudent :one
UPDATE students
SET name = $2, grade = $3, updated_at = now()
WHERE id = $1
RETURNING id, student_id, name, grade, active, created_at, updated_at;

-- name: SetStudentActive :one
UPDATE students
SET active = $2, updated_at = now()
WHERE id = $1
RETURNING id, student_id, name, grade, active, created_at, updated_at;

-- name: GetAttendanceForUpdate :one
SELECT id, student_id, attendance_date, checkin_at, checkout_at, created_at, updated_at
FROM attendance
WHERE student_id = $1 AND attendance_date = $2
FOR UPDATE;

-- name: GetAttendance :one
SELECT id, student_id, attendance_date, checkin_at, checkout_at, created_at, updated_at
FROM attendance
WHERE student_id = $1 AND attendance_date = $2;

-- name: CreateAttendance :one
INSERT INTO attendance (student_id, attendance_date, checkin_at)
VALUES ($1, $2, $3)
RETURNING id, student_id, attendance_date, checkin_at, checkout_at, created_at, updated_at;

-- name: CheckoutAttendance :one
UPDATE attendance
SET checkout_at = $3, updated_at = now()
WHERE student_id = $1 AND attendance_date = $2 AND checkout_at IS NULL
RETURNING id, student_id, attendance_date, checkin_at, checkout_at, created_at, updated_at;

-- name: ListAttendanceForDate :many
SELECT
    a.id,
    a.student_id,
    a.attendance_date,
    a.checkin_at,
    a.checkout_at,
    s.name,
    s.grade
FROM attendance a
JOIN students s ON s.student_id = a.student_id
WHERE a.attendance_date = $1
ORDER BY s.name ASC;
