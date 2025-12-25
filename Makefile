SKYLIGHT_AVAILABLE := $(shell test -d /System/Library/PrivateFrameworks/SkyLight.framework && echo 1 || echo 0)
override CXXFLAGS += -O2 -Wall -fobjc-arc -D"NS_FORMAT_ARGUMENT(A)=" -D"SKYLIGHT_AVAILABLE=$(SKYLIGHT_AVAILABLE)"

.PHONY: all clean install build run debug update dmg gui-app

all: AutoRaise AutoRaise.app

clean:
	rm -f AutoRaise
	rm -rf AutoRaise.app
	rm -rf build/
	rm -f AutoRaise.dmg

install: AutoRaise.app
	rm -rf /Applications/AutoRaise.app
	cp -r AutoRaise.app /Applications/

AutoRaise: AutoRaise.mm
        ifeq ($(SKYLIGHT_AVAILABLE), 1)
	    g++ $(CXXFLAGS) -o $@ $^ -framework AppKit -F /System/Library/PrivateFrameworks -framework SkyLight
        else
	    g++ $(CXXFLAGS) -o $@ $^ -framework AppKit
        endif

AutoRaise.app: AutoRaise Info.plist AutoRaise.icns
	./create-app-bundle.sh

# Build GUI app with launcher (requires Xcode)
gui-app: AutoRaise
	echo "Building AutoRaise.app with GUI launcher (will auto-resolve packages)..."
	mkdir -p build/logs
	echo "Resolving Swift Package Manager dependencies..."
	xcodebuild -resolvePackageDependencies \
		-project AutoRaise.xcodeproj \
		-scheme AutoRaise \
		-clonedSourcePackagesDirPath build/SourcePackages \
		2>&1 | tee build/logs/package-resolution.log || echo "Package resolution completed (warnings may be present)"
	echo "Building app..."
	bash -c 'set -o pipefail; \
	xcodebuild -project AutoRaise.xcodeproj \
		-scheme AutoRaise \
		-configuration Release \
		-derivedDataPath build \
		-clonedSourcePackagesDirPath build/SourcePackages \
		build 2>&1 | tee build/logs/build.log; \
	BUILD_STATUS=$$?; \
	if [ $$BUILD_STATUS -ne 0 ]; then \
		echo ""; \
		echo "=== BUILD FAILED WITH EXIT CODE: $$BUILD_STATUS ==="; \
		if [ -f "build/logs/build.log" ]; then \
			echo ""; \
			echo "=== SEARCHING FOR SWIFT ERRORS ==="; \
			grep -i "error:" build/logs/build.log | head -20 || echo "(no 'error:' found)"; \
			echo ""; \
			echo "=== SEARCHING FOR COMPILATION ERRORS ==="; \
			grep -i "compile.*error\|swift.*error\|failed.*compile" build/logs/build.log | head -20 || echo "(no compilation errors found)"; \
			echo ""; \
			echo "=== SEARCHING FOR FAILED COMMANDS ==="; \
			grep -i "failed\|failure" build/logs/build.log | head -20 || echo "(no failures found)"; \
			echo ""; \
			echo "=== LAST 200 LINES OF BUILD LOG ==="; \
			tail -200 build/logs/build.log; \
		else \
			echo "ERROR: Build log file not found at build/logs/build.log"; \
		fi; \
		exit $$BUILD_STATUS; \
	fi'
	@echo "Verifying package was resolved..."
	@if [ -d "build/SourcePackages/checkouts/MASShortcut" ]; then \
		echo "✓ MASShortcut package found"; \
	else \
		echo "⚠ MASShortcut package directory not found (may still work if built)"; \
	fi
	@echo "Checking if app bundle was created..."
	@if [ ! -d "build/Build/Products/Release/AutoRaise.app" ] && [ ! -d "build/Build/Products/AutoRaise.app" ]; then \
		echo "ERROR: App bundle not found in build output!"; \
		echo "Checking build directory structure..."; \
		find build/Build/Products -name "*.app" -type d 2>/dev/null | head -5 || echo "No .app bundles found"; \
		echo "Build products directory contents:"; \
		ls -la build/Build/Products/ 2>/dev/null || echo "Products directory not found"; \
		exit 1; \
	fi
	@APP_BUNDLE=""; \
	if [ -d "build/Build/Products/Release/AutoRaise.app" ]; then \
		APP_BUNDLE="build/Build/Products/Release/AutoRaise.app"; \
	elif [ -d "build/Build/Products/AutoRaise.app" ]; then \
		APP_BUNDLE="build/Build/Products/AutoRaise.app"; \
	fi; \
	if [ -z "$$APP_BUNDLE" ]; then \
		echo "ERROR: Failed to locate app bundle"; \
		exit 1; \
	fi; \
	echo "Found app bundle at: $$APP_BUNDLE"; \
	echo "Checking app bundle contents..."; \
	if [ ! -d "$$APP_BUNDLE/Contents/MacOS" ]; then \
		echo "WARNING: MacOS directory missing in source bundle"; \
		find "$$APP_BUNDLE" -maxdepth 3 -type d 2>/dev/null | head -10; \
	fi; \
	if [ ! -f "$$APP_BUNDLE/Contents/MacOS/AutoRaise" ]; then \
		echo "WARNING: AutoRaise executable missing in source bundle"; \
		echo "MacOS directory contents:"; \
		ls -la "$$APP_BUNDLE/Contents/MacOS/" 2>/dev/null || echo "MacOS directory not found"; \
		echo "Checking for any executables in app bundle:"; \
		find "$$APP_BUNDLE" -type f -perm +111 2>/dev/null | head -5 || echo "No executables found"; \
	fi; \
	cp -r "$$APP_BUNDLE" ./ || (echo "ERROR: Failed to copy app bundle" && exit 1)
	@echo "Verifying app bundle structure..."
	@if [ ! -d "AutoRaise.app/Contents/MacOS" ]; then \
		echo "ERROR: MacOS directory missing!"; \
		echo "App bundle contents:"; \
		find AutoRaise.app -maxdepth 3 -type d 2>/dev/null || true; \
		exit 1; \
	fi
	@if [ ! -f "AutoRaise.app/Contents/MacOS/AutoRaise" ]; then \
		echo "ERROR: AutoRaise executable missing from MacOS directory!"; \
		echo "MacOS directory contents:"; \
		ls -la AutoRaise.app/Contents/MacOS/ 2>/dev/null || echo "MacOS directory not accessible"; \
		exit 1; \
	fi
	@echo "Ensuring AutoRaise binary is in app bundle Resources..."
	@mkdir -p AutoRaise.app/Contents/Resources
	@if [ ! -f "AutoRaise.app/Contents/Resources/AutoRaise" ]; then \
		if [ -f "build/Build/Products/Release/AutoRaise.app/Contents/Resources/AutoRaise" ]; then \
			cp build/Build/Products/Release/AutoRaise.app/Contents/Resources/AutoRaise AutoRaise.app/Contents/Resources/; \
			echo "✓ Copied AutoRaise binary from Xcode build"; \
		elif [ -f "AutoRaise" ]; then \
			cp AutoRaise AutoRaise.app/Contents/Resources/; \
			echo "✓ Copied AutoRaise binary from project root"; \
		else \
			echo "ERROR: AutoRaise binary not found anywhere!"; \
			exit 1; \
		fi; \
	else \
		echo "✓ AutoRaise binary already in Resources"; \
	fi
	@chmod +x AutoRaise.app/Contents/Resources/AutoRaise
	@echo "Verifying MASShortcut framework is embedded..."
	@if [ ! -d "AutoRaise.app/Contents/Frameworks/MASShortcut.framework" ]; then \
		echo "MASShortcut framework not found, searching for it..."; \
		FRAMEWORK_FOUND=0; \
		if [ -d "build/Build/Products/Release/AutoRaise.app/Contents/Frameworks/MASShortcut.framework" ]; then \
			mkdir -p AutoRaise.app/Contents/Frameworks; \
			cp -r build/Build/Products/Release/AutoRaise.app/Contents/Frameworks/MASShortcut.framework AutoRaise.app/Contents/Frameworks/; \
			echo "✓ Copied MASShortcut framework from Xcode build app bundle"; \
			FRAMEWORK_FOUND=1; \
		elif [ -d "build/Build/Products/Release/MASShortcut.framework" ]; then \
			mkdir -p AutoRaise.app/Contents/Frameworks; \
			cp -r build/Build/Products/Release/MASShortcut.framework AutoRaise.app/Contents/Frameworks/; \
			echo "✓ Copied MASShortcut framework from build products"; \
			FRAMEWORK_FOUND=1; \
		elif [ -d "build/SourcePackages/checkouts/MASShortcut/Framework" ]; then \
			mkdir -p AutoRaise.app/Contents/Frameworks; \
			cp -r build/SourcePackages/checkouts/MASShortcut/Framework AutoRaise.app/Contents/Frameworks/MASShortcut.framework; \
			echo "✓ Copied MASShortcut framework from source packages"; \
			FRAMEWORK_FOUND=1; \
		fi; \
		if [ "$$FRAMEWORK_FOUND" -eq 0 ]; then \
			echo "⚠ Warning: MASShortcut framework not found - app may not work correctly"; \
			echo "Searched in:"; \
			echo "  - build/Build/Products/Release/AutoRaise.app/Contents/Frameworks/"; \
			echo "  - build/Build/Products/Release/"; \
			echo "  - build/SourcePackages/checkouts/MASShortcut/Framework"; \
		fi; \
	else \
		echo "✓ MASShortcut framework found"; \
	fi
	@echo "Ad-hoc signing app for Gatekeeper compatibility..."
	@codesign --force --deep --sign - AutoRaise.app || (echo "ERROR: Code signing failed" && exit 1)
	@echo "Verifying code signature..."
	@codesign --verify --verbose AutoRaise.app || (echo "ERROR: Code signature verification failed" && exit 1)
	@echo "App bundle structure:"
	@find AutoRaise.app -type f -o -type d | head -20
	@echo "Successfully created AutoRaise.app with GUI"

# Create DMG from GUI app
dmg: gui-app
	./create-dmg.sh

build: clean
	make CXXFLAGS="-DOLD_ACTIVATION_METHOD -DEXPERIMENTAL_FOCUS_FIRST"

run: build
	./AutoRaise -focusDelay 1

debug: build
	./AutoRaise -focusDelay 1 -verbose 1

update: build install
