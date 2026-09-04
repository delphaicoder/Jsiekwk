ARCHS = arm64
TARGET := iphone:clang:14.5:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

# ==== App chon anh + manual full-resolution depth ====
APPLICATION_NAME = DepthWallpaperApp
DepthWallpaperApp_FILES = DepthWallpaperApp/main.m DepthWallpaperApp/AppDelegate.m DepthWallpaperApp/SceneDelegate.m DepthWallpaperApp/ViewController.m DepthWallpaperApp/DWPresetManager.m DepthWallpaperApp/DWOptionsViewController.m
DepthWallpaperApp_FRAMEWORKS = UIKit Foundation PhotosUI Photos
DepthWallpaperApp_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
DepthWallpaperApp_LDFLAGS = -lc++abi
DepthWallpaperApp_INSTALL_PATH = /Applications
DepthWallpaperApp_BUNDLE_NAME = DepthWallpaper
DepthWallpaperApp_INFO_PLIST = DepthWallpaperApp/Resources/Info.plist
DepthWallpaperApp_RESOURCE_DIRS = DepthWallpaperApp/Resources


include $(THEOS_MAKE_PATH)/application.mk

# ==== Tweak SpringBoard hien overlay ====
TWEAK_NAME = DepthWallpaperTweak
DepthWallpaperTweak_FILES = Tweak.x DWWidget.x
DepthWallpaperTweak_FRAMEWORKS = UIKit Foundation
DepthWallpaperTweak_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -x objective-c
DepthWallpaperTweak_LDFLAGS = -lc++abi


include $(THEOS_MAKE_PATH)/tweak.mk

# Dam bao postinst/prerm luon co quyen thuc thi truoc khi dong goi — file nay hay
# bi mat quyen thuc thi qua cac lan nen/giai nen/upload lai, gay loi dpkg-deb
# "bad permissions" luc packaging. Chmod truc tiep tren thu muc staging (noi
# Theos thuc su lay file de dong goi .deb) de dam bao luon dung du nguon co the
# nao.
before-package::
	chmod 0755 "$(THEOS_STAGING_DIR)/DEBIAN/postinst" 2>/dev/null || true
	chmod 0755 "$(THEOS_STAGING_DIR)/DEBIAN/prerm" 2>/dev/null || true

# No automatic respring: install the package first, then respring manually if needed.
# DepthWallpaper 1.5.6: attach from SBFLockScreenDateView and order between clock and notifications.
