.DEFAULT_GOAL := help

# Determine this makefile's path.
# Be sure to place this BEFORE `include` directives, if any.
DEFAULT_BRANCH := main
THIS_FILE := $(lastword $(MAKEFILE_LIST))
VERSION := 0.0.0
COMMIT := $(shell git rev-parse HEAD)
CDIR = $(shell pwd)

CURRENT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
DEFAULT_BRANCH := main

help: ## Show this help.
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

clean-venv: ## re-create virtual env
	rm -rf .venv
	python3 -m venv .venv
	( \
       source .venv/bin/activate; \
       pip install --upgrade pip setuptools; \
    )

test: ## run pytest/taskcat with assertions
	( \
	   source .venv/bin/activate; \
	   pip install boto3 taskcat pytest; \
	   pytest -v; \
	)

quick-test: ## run taskcat to smoke test stack creation
	( \
	   source .venv/bin/activate; \
	   pip install boto3 taskcat pytest; \
	   taskcat test run; \
	)

lint:  ##  run cfn validate
	aws cloudformation validate-template --template-body file://topic.json

fmt: ## run gofmt
	@go fmt ${PKG_LIST}

static: lint test

bump: clean-venv  ## bump version in main branch
ifeq ($(CURRENT_BRANCH), $(DEFAULT_BRANCH))
	( \
	   source .venv/bin/activate; \
	   pip install bump2version; \
	   bump2version $(part); \
	)
else
	@echo "UNABLE TO BUMP - not on Main branch"
	$(info Current Branch: $(CURRENT_BRANCH), main: $(DEFAULT_BRANCH))
endif


git-status: ## require status is clean so we can use undo_edits to put things back
	@status=$$(git status --porcelain); \
	if [ ! -z "$${status}" ]; \
	then \
		echo "Error - working directory is dirty. Commit those changes!"; \
		exit 1; \
	fi

rebase: git-status ## rebase current feature branch on to the default branch
	git fetch && git rebase origin/$(DEFAULT_BRANCH)

.PHONY: build release static  lint test