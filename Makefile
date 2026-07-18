# Makefile cho WiFi Stressor App Testing
# Các command tiện ích để chạy tests và quality checks

.PHONY: help test test-unit test-widget test-integration coverage clean build analyze format install-deps

# Default target
help:
	@echo "WiFi Stressor App - Testing Commands"
	@echo ""
	@echo "Available commands:"
	@echo "  install-deps     - Install all dependencies"
	@echo "  test            - Run all tests"
	@echo "  test-unit       - Run unit tests only"
	@echo "  test-widget     - Run widget tests only"
	@echo "  test-integration - Run integration tests"
	@echo "  coverage        - Generate test coverage report"
	@echo "  analyze         - Run static analysis"
	@echo "  format          - Format code"
	@echo "  build           - Build debug APK"
	@echo "  release-aab     - Build optimized release AAB for Play Store (obfuscated, symbols split out)"
	@echo "  release-size    - Build arm64 AAB + print code-size breakdown"
	@echo "  clean           - Clean build files"
	@echo "  quality-check   - Run all quality checks"

# Install dependencies
install-deps:
	@echo "Installing Flutter dependencies..."
	flutter pub get
	@echo "Generating mocks..."
	flutter packages pub run build_runner build --delete-conflicting-outputs

# Run all tests
test: test-unit test-widget
	@echo "All tests completed!"

# Run unit tests
test-unit:
	@echo "Running unit tests..."
	flutter test test/unit/ --coverage

# Run widget tests
test-widget:
	@echo "Running widget tests..."
	flutter test test/widget/ --coverage

# Run integration tests
test-integration:
	@echo "Running integration tests..."
	flutter test test/integration/

# Generate coverage report
coverage:
	@echo "Generating coverage report..."
	flutter test --coverage
	genhtml coverage/lcov.info -o coverage/html
	@echo "Coverage report generated in coverage/html/"

# Static analysis
analyze:
	@echo "Running static analysis..."
	flutter analyze
	@echo "Analysis completed!"

# Format code
format:
	@echo "Formatting code..."
	dart format .
	@echo "Code formatted!"

# Build APK
build:
	@echo "Building APK..."
	flutter build apk --debug
	@echo "APK built successfully!"

# Build optimized release AAB for Play Store.
# --obfuscate + --split-debug-info đẩy ~11MB debug symbols / obfuscation map ra
# khỏi bundle (Play không giao cho user) và lưu riêng để giải mã crash sau này.
# GIỮ build/symbols/ theo từng version để decode được crash của bản đã phát hành.
release-aab: check-admob-test-id
	@echo "Building optimized release AAB..."
	flutter build appbundle --release \
		--obfuscate --split-debug-info=build/symbols
	@echo "AAB at build/app/outputs/bundle/release/app-release.aab"
	@echo "Debug symbols saved to build/symbols/ (keep these per release!)"

# Warn (don't block) if the active provider is AdMob but native config still
# ships Google's public test Application ID — harmless while AppLovin is
# active, but would silently no-fill in production if AdMob is live.
check-admob-test-id:
	@if grep -q "AdProvider.admob" lib/mckimquyen/widget/splash/splash_screen.dart 2>/dev/null && \
		(grep -q "3940256099942544~3347511713" android/app/src/main/AndroidManifest.xml 2>/dev/null || \
		 grep -q "3940256099942544~1458002511" ios/Runner/Info.plist 2>/dev/null); then \
		echo "WARNING: AdProvider.admob is active but AndroidManifest.xml/Info.plist still use Google's test Application ID — replace with your real AdMob App ID before shipping."; \
	fi

# Build single-ABI AAB and print the code-size breakdown.
release-size:
	@echo "Analyzing release size (arm64)..."
	flutter build appbundle --release \
		--target-platform android-arm64 --analyze-size

# Clean build files
clean:
	@echo "Cleaning build files..."
	flutter clean
	flutter pub get
	@echo "Clean completed!"

# Run all quality checks
quality-check: analyze format test coverage
	@echo "All quality checks completed!"

# Quick test (unit + widget only)
quick-test:
	@echo "Running quick tests..."
	flutter test test/unit/ test/widget/
	@echo "Quick tests completed!"

# Performance test
perf-test:
	@echo "Running performance tests..."
	flutter test test/unit/ --reporter=github
	flutter build apk --analyze-size
	@echo "Performance tests completed!"

# Setup CI environment
ci-setup:
	@echo "Setting up CI environment..."
	flutter doctor
	flutter pub get
	flutter packages pub run build_runner build --delete-conflicting-outputs
	@echo "CI setup completed!"

# Run tests with verbose output
test-verbose:
	@echo "Running tests with verbose output..."
	flutter test --reporter=expanded

# Check dependencies for updates
deps-check:
	@echo "Checking for dependency updates..."
	flutter pub outdated

# Security audit (basic)
security-audit:
	@echo "Running basic security audit..."
	flutter pub deps
	@echo "Check for known vulnerabilities in dependencies"

# Test specific file
test-file:
	@echo "Usage: make test-file FILE=test/unit/stressor_controller_test.dart"
ifdef FILE
	flutter test $(FILE) --coverage
else
	@echo "Please specify FILE parameter"
endif