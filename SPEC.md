# AfterCare -- A Student Checkin CheckOut App

## Tech Stack
* Rails 8.1.3.1, Propshaft, importmaps, Hotwire on, no build step
* Bootstrap CSS for UI
* Postgres for DB (using Docker)
* Mise for tools (ruby, etc)
* Justfile instead of Makefile


## Requirements

The goal of the app, is to allow parents to quickly and easily check in and out their students from an after school program. So the main table will be the attendance table. It should track created_at, updated_at, studentID, date, checkin datetime, checkout datetime. primary key is a serial counter. A student may be checked in and out multiple times per day. Timezone for the database should be USA Pacific. Do not store dates times in UTC. At most there will be ~1000 students in the database.

## Login
The app should support login with email/password to start, next version will allow signing in with Google. There are 2 roles, Admin and User. Only Admin role can access the Admin Page.

### DB Schema
```sql
-- Pin the database to Pacific (with DST). Reconnect after this.
-- ALTER DATABASE your_db SET timezone TO 'America/Los_Angeles';

CREATE TYPE role_enum AS ENUM ('Admin', 'User');

CREATE TABLE users (
  id          BIGSERIAL PRIMARY KEY,
  email       TEXT        NOT NULL UNIQUE,
  role        role_enum   NOT NULL DEFAULT 'User',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE students (
  id           BIGSERIAL PRIMARY KEY,
  first_name   TEXT        NOT NULL,
  last_name    TEXT        NOT NULL,
  grade        NUMBER NOT NULL,
  blackbaud_id TEXT        UNIQUE,
  guardians    TEXT[]      NOT NULL DEFAULT '{}',
  hidden       BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT students_name_key UNIQUE (first_name, last_name)
);

CREATE TABLE attendance (
  id           BIGSERIAL PRIMARY KEY,
  student_id   BIGINT      NOT NULL REFERENCES students (id) ON DELETE RESTRICT,
  day          DATE        NOT NULL,
  checkin      TIMESTAMPTZ NOT NULL,
  checkout     TIMESTAMPTZ,
  checkin_by   BIGINT      NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  checkout_by  TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT attendance_checkout_after_checkin
    CHECK (checkout IS NULL OR checkout > checkin)
);

-- At most one open visit per student, any day
CREATE UNIQUE INDEX attendance_one_open_per_student
  ON attendance (student_id)
  WHERE checkout IS NULL;

CREATE OR REPLACE FUNCTION attendance_enforce_visit_rules()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.checkout IS NOT NULL AND NEW.checkout <= NEW.checkin THEN
    RAISE EXCEPTION
      'checkout (%) must be after checkin (%)',
      NEW.checkout, NEW.checkin
      USING ERRCODE = 'check_violation';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM attendance a
    WHERE a.student_id = NEW.student_id
      AND a.checkout   IS NULL
      AND a.id         IS DISTINCT FROM NEW.id
  ) THEN
    RAISE EXCEPTION
      'student % already has an open checkin; checkout first',
      NEW.student_id
      USING ERRCODE = 'exclusion_violation';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER attendance_enforce_visit_rules
  BEFORE INSERT OR UPDATE OF student_id, day, checkin, checkout
  ON attendance
  FOR EACH ROW
  EXECUTE FUNCTION attendance_enforce_visit_rules();
```

## Front End
Main use case is running on a laptop, but app should also be Mobile Friendly. A User will log in to the app, and see a splash page, with a top bar hamburger menu with navigation to the various pages.
  
### Admin Page
Add and remove students from the system. Removing a student just hides the record from the checkin/out screens via a flag, never delete from the database. View a searchable table of all the days checkins. A date picker allows viewing other days.

### Checkin Page
It is important that this page has great UX to allow a User to quickly find and checkin many students quickly. Todays date at top of page, right/left arrows allow viewing other days. Text box at top of page that allows typing a few keys to filter records below. Row of buttons to filter by grade level (K,1,2,3,4,5,6 or all). Kindergarten is the letter K in the UI and grade 0 in the database. Show a list of all students in that grade, and the students that were present the day before should appear at the top of the list. The list item shows the student name, and a checkin button. When checkin is pressed, the button is replaced by the checkin time. Allow for multiple checkins per day, so if a student already has a checkin and checkout on a day, allow for another checkin to happen, while also showing the fact that a prev checkin/out has already ocurred. 

### Checkout Page
Same date and arrow header and filters. But only show students who have a checkin but not a checkout. The list item is student name and a checkout button. When pressed, the button turns into a time.
