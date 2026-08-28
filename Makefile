TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard ControlCenter

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = cowbellbattery

cowbellbattery_FILES = Tweak.xm
cowbellbattery_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
