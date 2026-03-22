APP_NAME = PinPoint
BUNDLE_ID = com.mits.pinpoint
DISPLAY_NAME = P!nPo!nt
SRC_DIR = Sources
OUT_DIR = build
APP_BUNDLE = $(OUT_DIR)/$(APP_NAME).app
DISPLAY_BUNDLE = $(OUT_DIR)/$(DISPLAY_NAME).app
CONTENTS_DIR = $(APP_BUNDLE)/Contents
MACOS_DIR = $(CONTENTS_DIR)/MacOS
RESOURCES_DIR = $(CONTENTS_DIR)/Resources

# Versioning
VERSION = 1.0.0
BUILD = 1

RELEASE_ZIP = Pinpoint_v$(VERSION).zip

SWIFT_FILES = $(wildcard $(SRC_DIR)/*.swift)
SWIFTC = swiftc
SWIFTC_FLAGS = -O -parse-as-library

# Load local configuration if it exists.
-include local.mk

# Set SIGN_IDENTITY to your Apple Development certificate name.
SIGN_IDENTITY ?= 

all: $(APP_BUNDLE)

$(APP_BUNDLE): $(SWIFT_FILES) Info.plist
	@rm -rf '$(DISPLAY_BUNDLE)'
	@mkdir -p $(MACOS_DIR)
	@mkdir -p $(RESOURCES_DIR)
	$(SWIFTC) $(SWIFTC_FLAGS) $(SWIFT_FILES) -o $(MACOS_DIR)/$(APP_NAME)
	@cp Info.plist $(CONTENTS_DIR)/
	@/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(CONTENTS_DIR)/Info.plist
	@/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD)" $(CONTENTS_DIR)/Info.plist
	if [ -d "Resources" ]; then cp -R Resources/* $(RESOURCES_DIR)/; fi
	@mv '$(APP_BUNDLE)' '$(DISPLAY_BUNDLE)'
	@xattr -rc '$(DISPLAY_BUNDLE)'
	@if [ -n "$(SIGN_IDENTITY)" ]; then \
		echo "Signing with identity: $(SIGN_IDENTITY)"; \
		codesign --force --deep --sign "$(SIGN_IDENTITY)" '$(DISPLAY_BUNDLE)'; \
	else \
		echo "Skipping codesign (SIGN_IDENTITY is empty)."; \
	fi
	@echo "Build complete: $(DISPLAY_BUNDLE) (v$(VERSION) build $(BUILD))"

release: all
	@rm -f $(RELEASE_ZIP)
	@zip -r $(RELEASE_ZIP) '$(DISPLAY_BUNDLE)'
	@echo "Release package created: $(RELEASE_ZIP)"

clean:
	rm -rf $(OUT_DIR)
	rm -f *.zip

help:
	@echo "Usage:"
	@echo "  make                Build the app (v$(VERSION) build $(BUILD))"
	@echo "  make release        Build and create a ZIP package for distribution"
	@echo "  make SIGN_IDENTITY= Build with a specific identity"
	@echo "  make clean          Remove build artifacts"
