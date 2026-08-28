ARCHS = arm64e
TARGET = iphone:clang:16.5:16.0
INSTALL_TARGET_PROCESSES = SpringBoard
ROOTLESS = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SimpleCowbell

SimpleCowbell_FILES = Tweak.x
SimpleCowbell_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
SimpleCowbell_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
