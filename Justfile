# Autoload a .env if one exists
set dotenv-load

default:
	@just --list --unsorted

db:
	docker compose up -d

sqlc:
	cd backend && sqlc generate

server:
	cd backend && go run ./cmd/server

web:
	cd frontend && pnpm dev

test:
	cd backend && go test ./...

build:
	cd frontend && pnpm build
