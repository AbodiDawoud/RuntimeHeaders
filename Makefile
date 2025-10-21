# Generic Makefile to build an unsigned IPA for sideloading
# Works with any Xcode project (.xcodeproj) or workspace (.xcworkspace)

CONFIGURATION = Release
BUILD_DIR = build
PAYLOAD_DIR = $(BUILD_DIR)/Payload

PROJECT := $(shell find . -maxdepth 1 -type d -name "*.xcodeproj" | head -1)

# Prefer workspace if it exists
BUILD_TYPE = project
BUILD_PATH = $(PROJECT)
APP_NAME := $(basename $(notdir $(PROJECT)))

# Scheme defaults to app name, can override: make ipa SCHEME=OtherScheme
SCHEME ?= $(APP_NAME)

.PHONY: clean ipa

# Clean previous build
clean:
	@rm -rf $(BUILD_DIR)

# Build and package IPA (unsigned)
ipa: clean
	@echo "Building $(BUILD_TYPE): $(BUILD_PATH)"
	@echo "Using scheme: $(SCHEME)"
	@echo "App name: $(APP_NAME)"
	@xcodebuild -project $(BUILD_PATH) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination 'generic/platform=iOS' \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGN_IDENTITY="" \
		PROVISIONING_PROFILE_SPECIFIER="" \
		BUILD_DIR=$(abspath $(BUILD_DIR)) \
		BUILD_ROOT=$(abspath $(BUILD_DIR)) \
		build
	@mkdir -p $(PAYLOAD_DIR)
	@cp -r $(BUILD_DIR)/$(CONFIGURATION)-iphoneos/$(APP_NAME).app $(PAYLOAD_DIR)
	@cd $(BUILD_DIR) && zip -r $(APP_NAME).ipa Payload
	@rm -rf $(PAYLOAD_DIR)
