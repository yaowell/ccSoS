THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SimpleCowbell

SimpleCowbell_FILES = Tweak.x
SimpleCowbell_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/tweak.mk
