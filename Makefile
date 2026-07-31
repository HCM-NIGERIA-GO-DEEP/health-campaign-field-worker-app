APP_DIR := apps/health_campaign_field_worker_app
FLUTTER ?= flutter

.PHONY: help run-dev run-qa run-prod build-apk-dev build-apk-qa build-apk-prod

help:
	@echo "Commands:"
	@echo "  make run-dev         Run Android app with .env.dev"
	@echo "  make run-qa          Run Android app with .env.qa"
	@echo "  make run-prod        Run Android app with .env.prod"
	@echo "  make build-apk-dev   Build release APK with .env.dev"
	@echo "  make build-apk-qa    Build release APK with .env.qa"
	@echo "  make build-apk-prod  Build release APK with .env.prod"

run-dev:
	cd $(APP_DIR) && $(FLUTTER) run --dart-define=ENV_FILE=.env.dev

run-qa:
	cd $(APP_DIR) && $(FLUTTER) run --dart-define=ENV_FILE=.env.qa

run-prod:
	cd $(APP_DIR) && $(FLUTTER) run --dart-define=ENV_FILE=.env.prod

build-apk-dev:
	cd $(APP_DIR) && $(FLUTTER) build apk --release --dart-define=ENV_FILE=.env.dev

build-apk-qa:
	cd $(APP_DIR) && $(FLUTTER) build apk --release --dart-define=ENV_FILE=.env.qa

build-apk-prod:
	cd $(APP_DIR) && $(FLUTTER) build apk --release --dart-define=ENV_FILE=.env.prod
