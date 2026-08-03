APP_DIR := apps/health_campaign_field_worker_app
APK_OUTPUT_DIR := $(APP_DIR)/build/app/outputs/flutter-apk
APK_SOURCE := $(APK_OUTPUT_DIR)/app-release.apk
ifeq ($(OS),Windows_NT)
FLUTTER ?= flutter.bat
else
FLUTTER ?= fvm flutter
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
	@mkdir -p $(APK_OUTPUT_DIR)
	@cp $(APK_SOURCE) $(APK_OUTPUT_DIR)/ITN_DEV.apk
	@echo "Generated: $(APK_OUTPUT_DIR)/ITN_DEV.apk"

build-apk-uat:
	cd $(APP_DIR) && $(FLUTTER) build apk --release --dart-define=ENV_FILE=.env.uat
	@mkdir -p $(APK_OUTPUT_DIR)
	@cp $(APK_SOURCE) $(APK_OUTPUT_DIR)/ITN_UAT.apk
	@echo "Generated: $(APK_OUTPUT_DIR)/ITN_UAT.apk"

build-apk-prod:
	cd $(APP_DIR) && $(FLUTTER) build apk --release --dart-define=ENV_FILE=.env.prod
	@mkdir -p $(APK_OUTPUT_DIR)
	@cp $(APK_SOURCE) $(APK_OUTPUT_DIR)/ITN_PROD.apk
	@echo "Generated: $(APK_OUTPUT_DIR)/ITN_PROD.apk"
