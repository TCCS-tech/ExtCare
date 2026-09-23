# Start Postgres, install gems, and prepare the database
setup:
    docker compose up -d --wait
    bundle install
    bin/rails db:prepare
    bin/rails db:seed

# Start Postgres
up:
    docker compose up -d --wait

# Stop Postgres
down:
    docker compose down

# Run the web server
server:
    bin/rails server

# Run tests
test:
    bin/rails test
