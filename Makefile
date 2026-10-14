# SocialCircle — command contract.
#
# These targets are what humans, the Agent Sparring stage agent, the
# independent reviewer and CI all run. Stage 1 of docs/plans/socialcircle-mvp.md
# creates backend/ and frontend/; until then the targets below fail loudly
# (never silently) because the directories do not exist.

SHELL := /bin/bash
.DEFAULT_GOAL := help

-include .env
export

COMPOSE      ?= docker compose
UV           ?= uv
NPM          ?= npm
BACKEND_DIR  := backend
FRONTEND_DIR := frontend
POSTGRES_PORT ?= 5440
POSTGRES_USER ?= socialcircle
POSTGRES_DB   ?= socialcircle

define require_dir
	@test -d $(1) || { echo "error: $(1)/ does not exist yet — it is created by Stage 1 of docs/plans/socialcircle-mvp.md"; exit 1; }
endef

.PHONY: help setup up down migrate test test-backend test-frontend lint typecheck e2e check env

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

env: ## Create .env from .env.example if it does not exist
	@test -f .env || { cp .env.example .env && echo "created .env from .env.example"; }

setup: env ## Install backend (uv) and frontend (npm ci + Playwright browser) dependencies; create the test database
	$(call require_dir,$(BACKEND_DIR))
	$(call require_dir,$(FRONTEND_DIR))
	cd $(BACKEND_DIR) && $(UV) sync --frozen
	cd $(FRONTEND_DIR) && $(NPM) ci
	cd $(FRONTEND_DIR) && npx playwright install chromium
	$(COMPOSE) up -d --wait db
	$(COMPOSE) exec -T db psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -tc "SELECT 1 FROM pg_database WHERE datname = '$(POSTGRES_DB)_test'" | grep -q 1 || \
		$(COMPOSE) exec -T db psql -U $(POSTGRES_USER) -d $(POSTGRES_DB) -c "CREATE DATABASE $(POSTGRES_DB)_test"

up: env ## Start db, backend and frontend with docker compose (waits for health checks)
	$(COMPOSE) up -d --build --wait

down: ## Stop the compose stack (keeps the database volume)
	$(COMPOSE) down

migrate: ## Apply database migrations (alembic upgrade head) against DATABASE_URL
	$(call require_dir,$(BACKEND_DIR))
	cd $(BACKEND_DIR) && $(UV) run alembic upgrade head

test-backend: ## Backend tests (pytest against the real test database)
	$(call require_dir,$(BACKEND_DIR))
	cd $(BACKEND_DIR) && $(UV) run pytest -q

test-frontend: ## Angular unit/component tests (headless, single run)
	$(call require_dir,$(FRONTEND_DIR))
	cd $(FRONTEND_DIR) && $(NPM) test -- --watch=false

test: test-backend test-frontend ## All unit and integration tests

lint: ## ruff (check + format --check) and eslint
	$(call require_dir,$(BACKEND_DIR))
	$(call require_dir,$(FRONTEND_DIR))
	cd $(BACKEND_DIR) && $(UV) run ruff check . && $(UV) run ruff format --check .
	cd $(FRONTEND_DIR) && $(NPM) run lint

typecheck: ## mypy (backend) and tsc (frontend)
	$(call require_dir,$(BACKEND_DIR))
	$(call require_dir,$(FRONTEND_DIR))
	cd $(BACKEND_DIR) && $(UV) run mypy
	cd $(FRONTEND_DIR) && $(NPM) run typecheck

e2e: ## Playwright browser tests against the running stack (make up first)
	$(call require_dir,$(FRONTEND_DIR))
	cd $(FRONTEND_DIR) && $(NPM) run e2e

check: lint typecheck test ## Everything CI runs except e2e
