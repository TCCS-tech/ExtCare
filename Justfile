set dotenv-load := true

default:
	@just --list --unsorted
    
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
    bin/rails server --binding 0.0.0.0

# Run tests
test:
    bin/rails test

migrate:
    bin/rails db:migrate

reset-db:
    bin/rails db:drop    
    bin/rails db:create
    bin/rails db:migrate
    bin/rails db:seed
    bin/rails runner script/import_students.rb 
    
script *cmd:
    bin/rails runner script/{{cmd}}.rb

rails *args:
    bin/rails {{args}}