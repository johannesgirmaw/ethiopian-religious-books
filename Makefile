.PHONY: help infra-up infra-down infra-logs dev run-dev seed openapi-export print-api-url reader-setup reader-run reader-run-android reader-run-macos reader-run-ios reader-build-apk-release reader-pubget reader-test pre-commit

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
	@echo "  make reader-pubget      - flutter pub get only"
	@echo "  make reader-build-apk-release - release APK/AAB → Render API (see script --help)"
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

reader-build-apk-release:
	@chmod +x scripts/build_reader_apk_release.sh 2>/dev/null || true
	@./scripts/build_reader_apk_release.sh

reader-pubget:
	cd apps/reader_flutter && flutter pub get

reader-test:
	cd apps/reader_flutter && flutter test

pre-commit:
	pre-commit run --all-files
