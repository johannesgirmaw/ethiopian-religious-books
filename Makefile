.PHONY: help infra-up infra-down infra-logs dev run-dev seed openapi-export print-api-url \
	reader-setup reader-run reader-run-android reader-run-macos reader-run-ios \
	reader-run-android-emulator reader-run-ios-simulator \
	reader-run-web reader-run-linux reader-run-windows \
	reader-build reader-build-apk-release reader-build-android reader-build-ios \
	reader-build-macos reader-build-web reader-build-linux reader-build-windows \
	reader-package-linux \
	reader-pubget reader-test pre-commit

help:
	@echo "Targets:"
	@echo "  make infra-up     - start postgres, redis, minio, mailhog"
	@echo "  make infra-down   - stop infra services"
	@echo "  make infra-logs   - follow infra logs"
	@echo "  make dev          - ./scripts/dev.sh (full compose in foreground)"
	@echo "  make run-dev      - ./scripts/run_dev.sh (Docker API + Flutter reader)"
	@echo "  make seed         - run Django seed_dev (when api container exists)"
	@echo "  make print-api-url  - show Swagger/health URLs (respects infra/.env API_PORT)"
	@echo "  make openapi-export - save OpenAPI JSON (API must be running; use print-api-url for port)"
	@echo "  ./scripts/verify_backend.sh - Docker smoke test (see script header for port overrides)"
	@echo "  make reader-setup       - ./scripts/setup_reader_flutter.sh (pub get; iOS pods only if INSTALL_READER_IOS=1)"
	@echo "  make reader-run         - ./scripts/run_reader_flutter.sh (Android or macOS fallback)"
	@echo "  make reader-run-android - Android only"
	@echo "  make reader-run-macos   - macOS desktop only"
	@echo "  make reader-run-ios     - ./scripts/run_reader_flutter.sh ios (optional)"
	@echo "  make reader-run-android-emulator - boot AVD + run (Android emulator)"
	@echo "  make reader-run-ios-simulator    - boot Simulator + run (iOS)"
	@echo "  make reader-run-web     - Chrome (web)"
	@echo "  make reader-run-linux   - Linux desktop"
	@echo "  make reader-run-windows - Windows desktop"
	@echo "  make reader-pubget      - flutter pub get only"
	@echo "  make reader-build       - ./scripts/build_reader_flutter.sh <platform>"
	@echo "  make reader-build-apk-release - release APK/AAB (Android shortcut)"
	@echo "  make reader-build-android   - same as reader-build-apk-release"
	@echo "  make reader-build-ios       - iOS release (macOS + Xcode)"
	@echo "  make reader-build-macos     - macOS .app release"
	@echo "  make reader-build-web       - static web build"
	@echo "  make reader-build-linux     - Linux desktop release"
	@echo "  make reader-build-windows   - Windows desktop release"
	@echo "  make reader-package-linux   - .deb (FORMATS=\"all\" adds rpm/flatpak; appimage is opt-in)"
	@echo "  make reader-test        - flutter test"
	@echo "  make pre-commit   - run all pre-commit hooks on repo"

infra-up:
	@test -f infra/.env || (echo "Creating infra/.env from .env.example" && cp infra/.env.example infra/.env)
	docker compose -f infra/docker-compose.yml --env-file infra/.env up -d

infra-down:
	@test -f infra/.env || cp infra/.env.example infra/.env
	docker compose -f infra/docker-compose.yml --env-file infra/.env down

infra-logs:
	@test -f infra/.env || cp infra/.env.example infra/.env
	docker compose -f infra/docker-compose.yml --env-file infra/.env logs -f

dev:
	@chmod +x scripts/dev.sh 2>/dev/null || true
	@./scripts/dev.sh

run-dev:
	@chmod +x scripts/run_dev.sh 2>/dev/null || true
	@./scripts/run_dev.sh

seed:
	docker compose -f infra/docker-compose.yml --env-file infra/.env exec api python manage.py seed_dev

seed-covers:
	docker compose -f infra/docker-compose.yml --env-file infra/.env exec api python manage.py seed_book_covers

print-api-url:
	@chmod +x scripts/print_api_url.sh 2>/dev/null || true
	@./scripts/print_api_url.sh

openapi-export:
	@mkdir -p packages/api_contract
	@PORT=$$(cd infra && docker compose --env-file .env port api 8000 2>/dev/null | sed 's/.*://' || echo 8000); \
	curl -sf "http://127.0.0.1:$$PORT/api/schema/?format=json" -o packages/api_contract/openapi.json
	@echo "Wrote packages/api_contract/openapi.json"

reader-setup:
	@chmod +x scripts/setup_reader_flutter.sh 2>/dev/null || true
	@./scripts/setup_reader_flutter.sh

reader-run:
	@chmod +x scripts/run_reader_flutter.sh 2>/dev/null || true
	@./scripts/run_reader_flutter.sh

reader-run-android:
	@chmod +x scripts/run_reader_flutter.sh 2>/dev/null || true
	@./scripts/run_reader_flutter.sh android

reader-run-macos:
	@chmod +x scripts/run_reader_flutter.sh 2>/dev/null || true
	@./scripts/run_reader_flutter.sh macos

reader-run-ios:
	@chmod +x scripts/run_reader_flutter.sh 2>/dev/null || true
	@./scripts/run_reader_flutter.sh ios

reader-run-android-emulator:
	@chmod +x scripts/run_reader_android_emulator.sh 2>/dev/null || true
	@./scripts/run_reader_android_emulator.sh

reader-run-ios-simulator:
	@chmod +x scripts/run_reader_ios_simulator.sh 2>/dev/null || true
	@./scripts/run_reader_ios_simulator.sh

reader-run-web:
	@chmod +x scripts/run_reader_web.sh 2>/dev/null || true
	@./scripts/run_reader_web.sh

reader-run-linux:
	@chmod +x scripts/run_reader_linux.sh 2>/dev/null || true
	@./scripts/run_reader_linux.sh

reader-run-windows:
	@chmod +x scripts/run_reader_windows.sh 2>/dev/null || true
	@./scripts/run_reader_windows.sh

reader-build:
	@chmod +x scripts/build_reader_flutter.sh 2>/dev/null || true
	@./scripts/build_reader_flutter.sh $(PLATFORM)

reader-build-apk-release reader-build-android:
	@chmod +x scripts/build_reader_apk_release.sh 2>/dev/null || true
	@./scripts/build_reader_apk_release.sh

reader-build-ios:
	@chmod +x scripts/build_reader_ios.sh 2>/dev/null || true
	@./scripts/build_reader_ios.sh

reader-build-macos:
	@chmod +x scripts/build_reader_macos.sh 2>/dev/null || true
	@./scripts/build_reader_macos.sh

reader-build-web:
	@chmod +x scripts/build_reader_web.sh 2>/dev/null || true
	@./scripts/build_reader_web.sh

reader-build-linux:
	@chmod +x scripts/build_reader_linux.sh 2>/dev/null || true
	@./scripts/build_reader_linux.sh

reader-build-windows:
	@chmod +x scripts/build_reader_windows.sh 2>/dev/null || true
	@./scripts/build_reader_windows.sh

reader-package-linux:
	@chmod +x scripts/package_reader_linux.sh 2>/dev/null || true
	@./scripts/package_reader_linux.sh $(FORMATS)

reader-pubget:
	cd apps/reader_flutter && flutter pub get

reader-test:
	cd apps/reader_flutter && flutter test

pre-commit:
	pre-commit run --all-files
