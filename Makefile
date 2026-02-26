.PHONY: help up down ps logs restart seed db-reset backend-build backend-run test test-unit test-v e2e

.DEFAULT_GOAL := help

help:
	@echo "YourOffice - Makefile targets"
	@echo ""
	@echo "  make up           - Start all services (docker compose up --build -d)"
	@echo "  make down         - Stop all services"
	@echo "  make ps           - Show running services"
	@echo "  make logs         - Follow logs (all services)"
	@echo "  make restart      - Restart all services"
	@echo "  make seed         - Run DB seed (requires DATABASE_URL in gobackend/.env)"
	@echo "  make db-reset     - Clean DB (truncate all) and re-run migrations + seed"
	@echo "  make backend-build - Build Go backend"
	@echo "  make backend-run  - Run Go backend locally (requires DATABASE_URL)"
	@echo "  make test         - Run unit tests and e2e tests"
	@echo "  make test-unit    - Run unit tests only (handlers, seed)"
	@echo "  make test-v       - Run unit tests with verbose output"
	@echo "  make e2e          - Run API e2e tests (requires backend + DB + seed)"

up:
	docker compose up -d

build:
	docker compose up --build -d

down:
	docker compose down

ps:
	docker compose ps

logs:
	docker compose logs -f

restart:
	docker compose restart

seed:
	cd gobackend && go run ./cmd/seed

db-reset:
	cd gobackend && go run ./cmd/seed -clean

backend-build:
	cd gobackend && go build -o /dev/null ./... && go build -o /dev/null

backend-run:
	cd gobackend && go run .

test: test-unit e2e

test-unit:
	cd gobackend && go run gotest.tools/gotestsum@latest --format testdox -- ./handlers ./seed

test-v:
	cd gobackend && go test ./handlers ./seed -v

# E2E tests hit a running backend. Start backend first, e.g. make up && make seed if db isn't seedded.
e2e:
	cd gobackend && go run gotest.tools/gotestsum@latest --format testdox -- ./e2e