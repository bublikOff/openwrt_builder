#!/bin/bash

#
OPENWRT_VERSION="24.10.0-rc2"
OPENWRT_TARGET="mediatek/filogic"
OPENWRT_SDK="gcc-13.3.0_musl.Linux-x86_64"

#
FEED_CONFIG=$(cat << 'EOF'
# CONFIG_ALL is not set
# CONFIG_ALL_KMODS is not set
# CONFIG_ALL_NONSHARED is not set
# CONFIG_DEVEL is not set
# CONFIG_SIGNED_PACKAGES is not set
CONFIG_PACKAGE_asterisk=m
CONFIG_PACKAGE_asterisk-chan-quectel=m
EOF
)

#
FEED_MAKEFILE=$(cat << 'EOF'
#
# Copyright (C) 2017 - 2018 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=asterisk-chan-quectel

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/mpmc/asterisk-chan-quectel.git
PKG_SOURCE_VERSION:=5552c365bfb319eed7cbbf6300a67028ab70db9e
PKG_SOURCE_DATE=2024-06-15
PKG_RELEASE:=1
PKG_MIRROR_HASH:=9d8ce9b76b635b5af50ff89a3f86153b389a54bd1d9ea517763cf048c6b1b9b8

PKG_FIXUP:=autoreconf

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=COPYRIGHT.txt LICENSE.txt
PKG_MAINTAINER:=Jiri Slachta <jiri@slachta.eu>

MODULES_DIR:=/usr/lib/asterisk/modules

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk
# asterisk-chan-quectel needs iconv
include $(INCLUDE_DIR)/nls.mk

define Package/asterisk-chan-quectel
	SUBMENU:=Telephony
	SECTION:=net
	CATEGORY:=Network
	URL:=https://github.com/mpmc/asterisk-chan-quectel
	DEPENDS:=asterisk $(ICONV_DEPENDS) +kmod-usb-acm +kmod-usb-serial +kmod-usb-serial-option +libusb-1.0 +alsa-lib
	TITLE:=Asterisk Quectel module support
endef

define Package/asterisk-chan-quectel/description
	Asterisk channel driver for Quectel module telephony.
endef

CONFIGURE_ARGS+= \
	--with-asterisk=$(STAGING_DIR)/usr/include \
	--with-astversion=20

ifeq ($(CONFIG_BUILD_NLS),y)
	CONFIGURE_ARGS+=--with-iconv=$(ICONV_PREFIX)/include
else
	CONFIGURE_ARGS+=--with-iconv=$(TOOLCHAIN_DIR)/include
endif

MAKE_FLAGS+=LD="$(TARGET_CC)"

CONFIGURE_VARS += \
	DESTDIR="$(MODULES_DIR)" \
	ac_cv_type_size_t=yes \
	ac_cv_type_ssize_t=yes

define Package/asterisk-chan-quectel/conffiles
	/etc/asterisk/quectel.conf
endef

define Package/asterisk-chan-quectel/install
	$(INSTALL_DIR) $(1)/etc/asterisk
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/ipkg-install/etc/asterisk/quectel.conf $(1)/etc/asterisk
	$(INSTALL_DIR) $(1)$(MODULES_DIR)
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/ipkg-install/$(MODULES_DIR)/chan_quectel.so $(1)$(MODULES_DIR)
endef

define Package/asterisk-chan-quectel/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
  echo
  echo "o-------------------------------------------------------------------o"
  echo "| asterisk-chan-quectel note                                         |"
  echo "o-------------------------------------------------------------------o"
  echo "| Adding the "asterisk" user to the "audio" group might be           |"
  echo "| required for Asterisk to be able to access the audio device.       |"
  echo "o-------------------------------------------------------------=^_^=-o"
  echo
fi
exit 0
endef

define Build/Prepare
	$(call Build/Prepare/Default)
ifeq ($(QUILT),)
ifeq ($(CONFIG_BUILD_NLS),y)
	$(SED) 's/\[iconv\], \[c iconv\]/[libiconv], [iconv]/' \
		"$(PKG_BUILD_DIR)/configure.ac"
endif
endif
endef

$(eval $(call BuildPackage,asterisk-chan-quectel))
EOF
)

# Build script
BUILD_SCRIPT=$(cat << 'EOF'
#!/bin/bash

#
OPENWRT_SDK_NAME="openwrt-sdk-${OPENWRT_VERSION}-$(echo $OPENWRT_TARGET | sed 's|/|-|g')_${OPENWRT_SDK}" 

# Update and install required packages
(apt update && \
    apt upgrade -y && 
    apt install -y git curl wget jq zstd swig uuid-dev cmake rsync gawk file unzip build-essential \
        libedit-dev libnewt-dev libssl-dev libncurses5-dev libsqlite3-dev libjansson-dev libasound2-dev libxml2-dev \
        python3 python3-distutils python3-setuptools
        
) || exit 1

# Download OpenWrt SDK
(mkdir -p "/build/openwrt"
    wget -q "https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${OPENWRT_TARGET}/${OPENWRT_SDK_NAME}.tar.zst" -O /tmp/openwrt_sdk.tar.zst && \
    tar --strip-components=1 --use-compress-program=unzstd -xvf /tmp/openwrt_sdk.tar.zst -C "/build/openwrt/" && rm "/tmp/openwrt_sdk.tar.zst"
) || exit 1

# Change directory to OpenWrt SDK
cd "/build/openwrt" || exit 1

## Configure feeds
(ln -s "/feed/" asterisk-modules && \
    cat ./feeds.conf.default > feeds.conf && \
    echo "src-link local /build/feed" >> feeds.conf) || exit 1

# Update and install feeds
./scripts/feeds update -a
./scripts/feeds install -a

# Change confing to our
(cp -f "/build/feed/asterisk-chan-quectel/diffconfig" "/build/openwrt/.config" && make defconfig) || exit 1

# Download, check and compile asterisk-chan-quectel module 
(make package/asterisk-chan-quectel/download V=sc && \
    make package/asterisk-chan-quectel/check FIXUP=1 V=sc && \
    make package/asterisk-chan-quectel/compile -j1 V=sc && \
    make package/index
) || exit 1

#
IPK_FILE=$(ls bin/packages/*/local/asterisk-chan-quectel*.ipk)

#
if [ -z "$IPK_FILE" ]; then
  echo "Failed to compile .ipk file."
  exit 1
fi

#
mkdir -p "/build/output" && cp "${IPK_FILE}" "/build/output/" || exit 1

EOF
)

#
TEMP_DIR="/tmp/asterisk-chan-quectel-build-root"

#
mkdir -p $(pwd)/output
mkdir -p "${TEMP_DIR}/feed/asterisk-chan-quectel"

#
echo "${FEED_CONFIG}" > "${TEMP_DIR}/feed/asterisk-chan-quectel/diffconfig"
echo "${FEED_MAKEFILE}" > "${TEMP_DIR}/feed/asterisk-chan-quectel/Makefile"

# Export build script to /tmp
echo "$BUILD_SCRIPT" > "${TEMP_DIR}/build.sh" || exit 1

# Start docker container to build asterisk-chan-quectel module
docker run --rm -it --pull always --workdir /build \
    -v $(pwd)/output:/build/output \
    -v "${TEMP_DIR}/feed":/build/feed \
    -v "${TEMP_DIR}/build.sh":/build/build.sh \
    -e OPENWRT_VERSION="${OPENWRT_VERSION}" \
    -e OPENWRT_TARGET="${OPENWRT_TARGET}" \
    -e OPENWRT_SDK="${OPENWRT_SDK}" \
    debian:latest /bin/bash /build/build.sh

# Remove build script
rm -rf "${TEMP_DIR}" > /dev/null 2> /dev/null
