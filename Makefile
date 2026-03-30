APP_NAME := VoiceIME
BUILD_DIR := .build/release
DIST_DIR := Dist
APP_BUNDLE := $(DIST_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
PLIST := Resources/App/Info.plist
EXECUTABLE := $(BUILD_DIR)/$(APP_NAME)
SWIFT_ENV := HOME=$(CURDIR) CLANG_MODULE_CACHE_PATH=$(CURDIR)/.build/ModuleCache SWIFT_MODULECACHE_PATH=$(CURDIR)/.build/ModuleCache

.PHONY: build run install clean

build:
	$(SWIFT_ENV) swift build -c release --disable-sandbox
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	cp "$(PLIST)" "$(CONTENTS_DIR)/Info.plist"
	cp "$(EXECUTABLE)" "$(MACOS_DIR)/$(APP_NAME)"
	codesign --force --deep --sign - "$(APP_BUNDLE)"

run: build
	open "$(APP_BUNDLE)"

install: build
	rm -rf "$$HOME/Applications/$(APP_NAME).app"
	mkdir -p "$$HOME/Applications"
	cp -R "$(APP_BUNDLE)" "$$HOME/Applications/$(APP_NAME).app"

clean:
	$(SWIFT_ENV) swift package clean --disable-sandbox
	rm -rf "$(DIST_DIR)"
