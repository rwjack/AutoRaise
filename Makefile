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
	@echo "Building AutoRaise.app with GUI launcher (will auto-resolve packages)..."
	@mkdir -p build/logs
	@xcodebuild -project AutoRaise.xcodeproj \
		-scheme AutoRaise \
		-configuration Release \
		-derivedDataPath build \
		-clonedSourcePackagesDirPath build/SourcePackages \
		build 2>&1 | tee build/logs/build.log || (echo "=== BUILD FAILED ===" && echo "Extracting Swift compilation errors:" && grep -E "(error:|warning:.*MASShortcut)" build/logs/build.log | head -20 && echo "" && echo "Full error context:" && grep -A 10 "error:" build/logs/build.log | head -50 && exit 1)
	@echo "Verifying package was resolved..."
	@if [ -d "build/SourcePackages/checkouts/MASShortcut" ]; then \
		echo "✓ MASShortcut package found"; \
	else \
		echo "⚠ MASShortcut package directory not found (may still work if built)"; \
	fi
	@cp -r build/Build/Products/Release/AutoRaise.app ./ || cp -r build/Build/Products/AutoRaise.app ./
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
