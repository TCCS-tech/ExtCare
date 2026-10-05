# ExtendedCare

Parents and staff check students in and out of the after school program. Times are stored in Pacific time (`America/Los_Angeles`).

## Run

```sh
just setup
just server
```

Open http://localhost:3000

## Google sign-in

Password sign-in remains available. Google sign-in uses the same user record:
existing permissions and passwords are preserved, and new Google users receive
the staff (`User`) role. Gmail and Google Workspace accounts with a verified
matching email are linked automatically. For an existing third-party email
address, the user must enter their existing password once after Google sign-in
to link the accounts (within ten minutes). Subsequent sign-ins can use either
method. Google identities are matched by their stable subject ID after linking;
Google email changes do not change the app's email or permissions. New Google
users can use Forgot password to set a password for manual sign-in.

To enable the button:

1. Create a **Web application** OAuth client in Google Cloud and configure its
   consent screen for the intended users (add test users if it is in testing).
2. Add authorized redirect URIs matching each app origin exactly:
   `http://localhost:3000/api/auth/callback/google` for development and
   `https://YOUR_APP_HOST/api/auth/callback/google` for production.
3. Set `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in the app environment;
   keep the secret in the host's secret manager. Both must be set for the button
   and OAuth middleware to be enabled. These are separate from Gmail SMTP settings.
4. Run `bundle install` and `bin/rails db:migrate`, then restart/redeploy.

Sign-in requests are POST forms protected by Rails CSRF validation, and callbacks
use OAuth state validation. Only identity scopes are requested; Google access
tokens are not stored. Anyone who can complete Google sign-in may receive staff
access, as with the requested default; there is no domain or invitation restriction.

## PWA updates

Open pages check `/build` on load, every minute while visible, and when returning
to the foreground or reconnecting. A changed build shows a Reload button; it
never automatically reloads or interrupts data entry. The version is a digest of
application code, configuration, public source files, and Gemfile.lock computed
at boot, so replicas of the same build agree without deployment configuration.
The version endpoint and browser checks disable caching. Existing installations
need to load this feature once before they can detect subsequent deployments.

## Password reset email

Production sends password reset messages through Gmail SMTP. Configure these
environment variables in the production host (keep the password in its secret
manager; do not commit it):

| Variable | Value |
| --- | --- |
| `SMTP_ADDRESS` | `smtp.gmail.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USERNAME` | Full Gmail or Google Workspace email address |
| `SMTP_PASSWORD` | Google App Password (not the account password) |
| `MAILER_FROM` | Same address as `SMTP_USERNAME` |
| `APP_HOST` | Public app hostname, without `https://` (for example `app.example.com`) |

For Google, turn on 2-Step Verification, then create an App Password in your
Google Account security settings. If Google Workspace blocks App Passwords,
an administrator must allow them or you will need a transactional email
provider. Set the variables on the production host and restart/redeploy the
app. Password reset links use HTTPS and `APP_HOST`.

These settings apply to production. Local development uses Rails' existing
development mail configuration.

| Email | Password | Role |
| --- | --- | --- |
| admin@example.com | password | Admin |
| staff@example.com | password | User |

Postgres runs in Docker. `just test` runs the test suite. `just down` stops the database.

## Database schema

All application tables, types, functions, and Rails metadata live in `extcare`.
The connection search path is `extcare` only, so missing schema setup cannot
silently create tables in `public`.

Keep `db/structure.sql` checked in: it creates the schema and preserves the
PostgreSQL enums and attendance trigger. Rails loads it when preparing a fresh
database, including parallel test databases. Run `bin/rails db:prepare` after
pulling migrations, or `RAILS_ENV=test bin/rails db:prepare` for just the test
database. PostgreSQL client tools (`psql` and `pg_dump`) must be on `PATH`.

## Documents

Admins can create and edit documents from Admin → Documents. Lexxy stores rich
text HTML in `documents.body`; attachments and upload endpoints are disabled.

The PostgreSQL `documents_version_history` trigger saves the complete **previous**
row as JSONB in `extcare.versions.data` on every UPDATE or DELETE, including direct
SQL and bulk changes. `table_name` is `documents`, and `created_at` records the
version time. Inserts do not create versions. Versions participate in the same
transaction as the change, so rolled-back changes leave no history. This table
is for database administrators and has no application UI.

## New school year

Admin → New School Year runs a backup/download/confirmation wizard. A background
Active Job exports all database columns and rows from `students`, `attendance`,
and `billing_records` into three XLSX files inside one ZIP. Exports use a single
repeatable-read snapshot, 500-row batches with query caching disabled, disk-backed
ZIP streams, and additional worksheets when Excel's row limit is reached. Values
are stored as text to preserve IDs and avoid executing spreadsheet formulas;
arrays are JSON and timestamps include their offset. A cell exceeding Excel's
32,767-character limit fails the backup rather than silently losing data.

The authenticated admin must request the download and type `I UNDERSTAND` exactly.
The browser cannot verify that a file was saved, so the confirmation page asks the
admin to check that the download completed. The final transaction locks all three
tables, compares their contents against the backup, and rejects changed data. It
then runs `TRUNCATE ... RESTART IDENTITY` for those three tables only. Repeated
confirmation requests cannot delete records entered after a completed reset.

Run `bin/rails db:migrate` before using this feature. Backup archives are private
files outside the public directory, retained at `storage/school_year_backups`.
Set `SCHOOL_YEAR_BACKUP_DIRECTORY` to a persistent, shared private volume if the
app has multiple instances or deploys with ephemeral storage; the job and web
processes must see the same directory. Plan archive retention according to the
school's needs. The app currently uses Rails' in-process async job adapter: keep
the process running during export. Interrupted jobs offer a fresh backup after
two hours; a durable Active Job adapter can be configured for deployments that
need jobs to survive restarts. The browser polls every two seconds while waiting.

## Import students

Admin → Import Data accepts the `students.xlsx` extracted from a school year
backup (maximum 20 MB compressed and 256 MB expanded). Keep every original
column header; all worksheets use the same headers. The importer streams rows,
uses disk-backed shared strings for files resaved in Excel, and rejects formulas,
invalid values, duplicate Blackbaud/student ID pairs, and malformed files.

Students are matched by the unique `(blackbaud_id, student_id)` pair, with the
same identifier normalization used by student forms. Existing records retain
their database ID and creation timestamp, preserving attendance and billing
links. New rows receive new database IDs and timestamps; backup metadata columns
are ignored. An identical re-import makes no changes, including timestamps.
Boolean flags use `true`/`false` or `1`/`0`; grade is `0` through `6`; guardian and
additional adult lists are JSON arrays of strings, as written by the backup.

Imports run in one transaction, serialize student writes, and stop without any
changes if a row fails validation. Students absent from the file remain; existing
attendance and billing records are not imported or recalculated. The page reports
added, updated, and unchanged student counts on completion.
