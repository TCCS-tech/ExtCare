# AfterCare

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
