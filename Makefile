APP_DIR := apps/health_campaign_field_worker_app
ifeq ($(OS),Windows_NT)
FLUTTER ?= flutter.bat
else
FLUTTER ?= flutter
endif

.PHONY: help run-dev run-uat run-prod build-apk-dev build-apk-uat build-apk-prod

help:
	@echo "Commands:"
	@echo "  make run-dev         Run Android app with .env.dev"
	@echo "  make run-uat         Run Android app with .env.uat"
	@echo "  make run-prod        Run Android app with .env.prod"
	@echo "  make build-apk-dev   Build release APK with .env.dev"
	@echo "  make build-apk-uat   Build release APK with .env.uat"
	@echo "  make build-apk-prod  Build release APK with .env.prod"

run-dev:
	cd $(APP_DIR) && $(FLUTTER) run --dart-define=ENV_FILE=.env.dev

run-uat:
	cd $(APP_DIR) && $(FLUTTER) run --dart-define=ENV_FILE=.env.uat

run-prod:
	cd $(APP_DIR) && $(FLUTTER) run --dart-define=ENV_FILE=.env.prod

build-apk-dev:
	cd $(APP_DIR) && $(FLUTTER) build apk --release --dart-define=ENV_FILE=.env.dev

build-apk-uat:
	cd $(APP_DIR) && $(FLUTTER) build apk --release --dart-define=ENV_FILE=.env.uat

build-apk-prod:
	cd $(APP_DIR) && $(FLUTTER) build apk --release --dart-define=ENV_FILE=.env.prod
