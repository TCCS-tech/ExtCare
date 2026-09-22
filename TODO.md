# Student Checkin CheckOut App

## Tech Stack
* Go for backend, SQLC for Db connection, Fiber for web framework with standard golang html templates
* react front end, no server rendering
* pnpm for package mgmt
* bootstrap css for UI
* Postgres for DB
* Mise for tools (Go, node, etc)
* Justfile instead of Makefile


## Requirements

The goal of the app, is to allow parents to quickly and easily check in and out their students from an after school program. So the main table will be the attendance table. It should track created_at, updated_at, studentID, date, checkin datetime, checkout datetime. primary key is a serial counter. Unique index on studentID/date. 

### Admin
The app should support multiple admin accounts (email/password to start, in future would also add OAuth for google) that can add and remove students from the system. Removing a student just disables the record, never delete. A student record is name, grade, and a unique alphanumeric studentID.

### Print Student List
The Admin can print out a student list on a PDF, formatted to fit many students on a single page. The list should be formatted as cards with student name, grade, and a QR code of their studentID.

### Front Page
The front page of the app will require no login. It will have a placeholder logo for TCCS and the name of the app "Aftercare Checkin", and a button to Checkin your student and another to Checkout your student.

### Checkin Page
This page will allow the user to scan a QR code of a studentID, which wil then pop up a confirmation modal "Check in Bobby Smith (6th grade)?" If the user confirms, create a attendance record in the DB.

### Checkout Page
This page will allow the user to scan a QR code of a studentID, which wil then pop up a confirmation modal "Check out Bobby Smith (6th grade)?" If the user confirms, write the checkout datetime to the attendance record. If the student is not checked in, they are not able to check out.
