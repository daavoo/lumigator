.PHONY: local-up local-down local-logs clean-docker-buildcache clean-docker-images clean-docker-containers start-lumigator-external-services start-lumigator stop-lumigator

SHELL:=/bin/bash
UNAME:= $(shell uname -o)

#used in docker-compose to choose the right Ray image
ARCH := $(shell uname -m)
RAY_ARCH_SUFFIX :=

ifeq ($(ARCH), arm64)
	RAY_ARCH_SUFFIX := -aarch64
endif

LOCAL_DOCKERCOMPOSE_FILE:= docker-compose.yaml
DEV_DOCKER_COMPOSE_FILE:= .devcontainer/docker-compose.override.yaml

.env:
	@if [ ! -f .env ]; then cp .env.example .env; echo ".env created from .env.example"; fi

# Launches Lumigator in 'development' mode (all services running locally, code mounted in)
local-up: .env
	uv run pre-commit install
	RAY_ARCH_SUFFIX=$(RAY_ARCH_SUFFIX) docker compose --profile local -f $(LOCAL_DOCKERCOMPOSE_FILE) -f ${DEV_DOCKER_COMPOSE_FILE} up --watch --build

local-down:
	docker compose --profile local -f $(LOCAL_DOCKERCOMPOSE_FILE) down

local-logs:
	docker compose -f $(LOCAL_DOCKERCOMPOSE_FILE) logs

# Launches lumigator in 'user-local' mode (All services running locally, using latest docker container, no code mounted in)
start-lumigator: .env
	RAY_ARCH_SUFFIX=$(RAY_ARCH_SUFFIX) docker compose --profile local -f $(LOCAL_DOCKERCOMPOSE_FILE) up -d

# Launches lumigator with no code mounted in, and forces build of containers (used in CI for integration tests)
start-lumigator-build: .env
	RAY_ARCH_SUFFIX=$(RAY_ARCH_SUFFIX) docker compose --profile local -f $(LOCAL_DOCKERCOMPOSE_FILE) up -d --build

# Launches lumigator without local dependencies (ray, S3)
start-lumigator-external-services: .env
	docker compose -f $(LOCAL_DOCKERCOMPOSE_FILE) up -d

stop-lumigator:
	RAY_ARCH_SUFFIX=$(RAY_ARCH_SUFFIX) docker compose --profile local -f $(LOCAL_DOCKERCOMPOSE_FILE) down

clean-docker-buildcache:
	docker builder prune --all -f

clean-docker-containers:
	docker rm -vf $$(docker container ls -aq)

clean-docker-images:
	docker rmi -f $$(docker image ls -aq)

clean-docker-all: clean-docker-containers clean-docker-buildcache clean-docker-images

clean-all: clean-docker-buildcache clean-docker-containers

test:
	make start-lumigator-build
	cd lumigator/python/mzai/backend; SQLALCHEMY_DATABASE_URL=sqlite:///local.db uv run pytest
	cd lumigator/python/mzai/sdk; uv run pytest -o python_files="test_*.py int_test_*.py"
	make stop-lumigator
