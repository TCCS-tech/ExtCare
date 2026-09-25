# ExtendedCare

Parents and staff check students in and out of the after school program. Times are stored in Pacific time (`America/Los_Angeles`).

## Run

```sh
just setup
just server
```

Open http://localhost:3000

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
