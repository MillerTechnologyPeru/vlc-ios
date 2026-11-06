# VLC for iOS 6: builds build/iOS6/VLCiOS6.app (armv7, iOS 6.0) with Embedded
# Swift, Swift-iOS6's SwiftUI library and the iOS 6 MobileVLCKit.framework.
#
#   make           build the app and check its imports against iOS 6
#   make install   copy it to the device (jailbroken, SSH over iproxy)
#   make run       launch it (the device must be unlocked)
#   make media FILES="a.mp4 b.mkv"   copy media into the app's Documents
#
# SWIFT_IOS6 is a Swift-iOS6 checkout (github.com/colemancda/Swift-iOS6) with
# its SDK set up (`make sdk` there). VLCKIT is a VLCKit checkout on the
# swift-ios6 branch (github.com/MillerTechnologyPeru/vlckit) after
# `./buildMobileVLCKit.sh -6`.

ROOT       := $(abspath ../../..)
SWIFT_IOS6 ?= $(abspath $(ROOT)/../Swift-iOS6)
VLCKIT     ?= $(abspath $(ROOT)/../VLCKit-iOS6-3)
APP        := VLCiOS6
BUILD      := $(ROOT)/build/iOS6
BUNDLE     := $(BUILD)/$(APP).app
SDK        := $(SWIFT_IOS6)/sdk/iPhoneOS9.3.sdk
SSH_CONF   ?= $(SWIFT_IOS6)/ipod-ssh.conf
SSH_HOST   ?= ipod
# The app's Documents folder (apps in /Applications run as mobile)
DOCUMENTS  ?= /var/mobile/Documents

# VLC sources shared with the iOS app, which build with Embedded Swift
SHARED := Sources/Playback/Player/VideoPlayer-iOS/AspectRatio.swift \
          Sources/Extensions/Data?Structures/Array+Safety.swift
SHARED_DIR := $(BUILD)/shared
SHARED_LINKS := $(addprefix $(SHARED_DIR)/,$(notdir $(SHARED)))

APP_SRCS := $(abspath $(wildcard *.swift)) $(SHARED_LINKS)

# MobileVLCKit with iOS 6's own libSystem and libc++ stubs (see VLCKit's
# Packaging/iOS6/README.md). -ObjC: Swift reaches VLCKit's classes by name,
# so nothing references them at link time. No AudioUnit.framework, which
# iOS 6 doesn't have.
FRAMEWORKS := UIKit Foundation CoreFoundation AVFoundation AudioToolbox CoreAudio \
              CoreGraphics CoreText CoreVideo CoreMedia OpenGLES QuartzCore Security \
              SystemConfiguration CFNetwork MediaPlayer ImageIO MobileCoreServices
LDFLAGS := -arch armv7 -isysroot $(SDK) -miphoneos-version-min=6.0 \
           -L$(VLCKIT)/build/iOS6/link-stubs/usr/lib -F$(VLCKIT)/build/iOS6 \
           -framework MobileVLCKit -Wl,-ObjC $(addprefix -framework ,$(FRAMEWORKS)) \
           -lc++ -lc++abi -liconv -lbz2 -lz -lresolv -lsqlite3 -Wl,-dead_strip

SWIFTUI_MAKE = $(MAKE) -C $(SWIFT_IOS6)/SwiftUI APP=$(APP) APP_DIR=$(CURDIR) BUILD=$(BUILD) \
               APP_SRCS="$(APP_SRCS)" LDFLAGS="$(LDFLAGS)" \
               SSH_CONF=$(SSH_CONF) SSH_HOST=$(SSH_HOST)

.PHONY: all install run media autoplay log census clean

all: $(SHARED_LINKS)
	$(SWIFTUI_MAKE) all
	mkdir -p $(BUNDLE)/en.lproj
	cp $(ROOT)/Resources/en.lproj/Localizable.strings $(BUNDLE)/en.lproj/
	python3 -I $(VLCKIT)/Packaging/iOS6/check_imports.py \
	  $(VLCKIT)/Packaging/iOS6/ios-6.1.6-armv7-exports.txt $(BUNDLE)/$(APP)

# make can't name files with spaces, so link the shared ones
$(SHARED_DIR)/%.swift:
	@mkdir -p $(SHARED_DIR)
	ln -sf "$(ROOT)/$(subst ?, ,$(filter %/$*.swift,$(SHARED)))" "$@"

# The app is ~40 MB (VLCKit and its plugins), more than the system partition
# of an 8 GB iPod has left, so it goes on /var with a link in /Applications.
APP_HOME ?= /var/stash/Applications

install: all
	COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -C $(BUILD) -cf - $(APP).app | \
	  ssh -F $(SSH_CONF) $(SSH_HOST) 'mkdir -p $(APP_HOME) && rm -rf /Applications/$(APP).app $(APP_HOME)/$(APP).app && \
	    tar -C $(APP_HOME) -xf - && chown -R root:wheel $(APP_HOME)/$(APP).app && \
	    ln -s $(APP_HOME)/$(APP).app /Applications/$(APP).app && su mobile -c uicache'

run:
	$(SWIFTUI_MAKE) run

media:
	@test -n "$(FILES)" || { echo 'usage: make media FILES="a.mp4 b.mkv"'; exit 2; }
	for f in $(FILES); do \
	  ssh -F $(SSH_CONF) $(SSH_HOST) "mkdir -p $(DOCUMENTS) && chown mobile:mobile $(DOCUMENTS) && cat > '$(DOCUMENTS)/$$(basename $$f)' && chown mobile '$(DOCUMENTS)/$$(basename $$f)'" < "$$f" || exit 1; \
	done

# Plays FILE (a name in Documents) at the next launch, then launches the app
autoplay:
	@test -n "$(FILE)" || { echo 'usage: make autoplay FILE=movie.mp4'; exit 2; }
	ssh -F $(SSH_CONF) $(SSH_HOST) "printf '%s' '$(FILE)' > $(DOCUMENTS)/.autoplay && chown mobile $(DOCUMENTS)/.autoplay && killall $(APP) 2>/dev/null; true"
	$(SWIFTUI_MAKE) run

# Type-checks VLC's iOS Swift with Embedded Swift against the iOS 6 SDK
# overlays (SDK/) and summarizes the errors left
census:
	SWIFT_IOS6=$(SWIFT_IOS6) SDK/census.sh $(BUILD)/census

# The app's and libvlc's log
log:
	ssh -F $(SSH_CONF) $(SSH_HOST) cat $(DOCUMENTS)/VLC.log

clean:
	rm -rf $(BUILD)
