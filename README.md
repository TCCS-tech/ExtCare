# ExtendedCare

Parents and staff check students in and out of the after school program. Times are stored in Pacific time (`America/Los_Angeles`).

## Run

```sh
just setup
just server
```

Open http://localhost:3000

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
