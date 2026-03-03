.PHONY: build run test clean app install uninstall dmg

BINARY=team-sync-web
APP_NAME=Dynamic Horizon Sync

build:
	go build -o $(BINARY) .

run: build
	./$(BINARY)

test:
	go test ./internal/rsync/ -v

clean:
	rm -rf $(BINARY) "$(APP_NAME).app"

# Build macOS .app bundle
app: build
	@echo "==> Generating icon..."
	@cd macos && bash gen-icon.sh
	@echo "==> Compiling Swift wrapper..."
	swiftc -O -o macos/TeamSync macos/main.swift \
		-framework Cocoa -framework WebKit
	@echo "==> Assembling $(APP_NAME).app..."
	@rm -rf "$(APP_NAME).app"
	@mkdir -p "$(APP_NAME).app/Contents/MacOS"
	@mkdir -p "$(APP_NAME).app/Contents/Resources"
	@cp macos/Info.plist "$(APP_NAME).app/Contents/"
	@cp macos/TeamSync "$(APP_NAME).app/Contents/MacOS/"
	@cp $(BINARY) "$(APP_NAME).app/Contents/MacOS/"
	@cp macos/AppIcon.icns "$(APP_NAME).app/Contents/Resources/"
	@chmod +x "$(APP_NAME).app/Contents/MacOS/TeamSync"
	@chmod +x "$(APP_NAME).app/Contents/MacOS/$(BINARY)"
	@echo "==> Done! Open with: open \"$(APP_NAME).app\""

install: app
	@bash install.sh

uninstall:
	@bash uninstall.sh

dmg: app
	@bash macos/create-dmg.sh
