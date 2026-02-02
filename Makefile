.PHONY: help up down ps logs restart backend-build backend-run

.DEFAULT_GOAL := help

help:
	@echo "YourOffice - Makefile targets"
	@echo ""
	@echo "  make up           - Start all services (docker compose up --build -d)"
	@echo "  make down         - Stop all services"
	@echo "  make ps           - Show running services"
	@echo "  make logs         - Follow logs (all services)"
	@echo "  make restart      - Restart all services"
	@echo "  make backend-build - Build Go backend"
	@echo "  make backend-run  - Run Go backend locally (requires DATABASE_URL)"

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

backend-build:
	cd gobackend && go build -o /dev/null ./... && go build -o /dev/null

backend-run:
	cd gobackend && go run .
