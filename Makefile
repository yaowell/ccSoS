THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:15.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SimpleCowbell

SimpleCowbell_FILES = Tweak.x
SimpleCowbell_CFLAGS = -fobjc-arc
SimpleCowbell_STRIP = 1

include $(THEOS)/makefiles/tweak.mk