include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = KeyPilot

KeyPilot_FILES = main.m KPAppDelegate.m ../Shared/KPShared.m
KeyPilot_CFLAGS = -fobjc-arc -I../Shared
KeyPilot_FRAMEWORKS = UIKit Foundation
KeyPilot_CODESIGN_FLAGS = -Sentitlements.plist
KeyPilot_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk
