include $(THEOS)/makefiles/common.mk

TWEAK_NAME = KeyPilotHook

KeyPilotHook_FILES = Tweak.xm ../Shared/KPShared.m
KeyPilotHook_CFLAGS = -fobjc-arc -I../Shared
KeyPilotHook_FRAMEWORKS = UIKit Foundation
KeyPilotHook_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk
