#!/bin/bash

#
# https://openwrt.org/docs/guide-user/additional-software/imagebuilder
# https://hub.docker.com/r/openwrt/imagebuilder/tags?name=filogic
#

#
VERSION=24.10.0-rc2
PROFILE=bananapi_bpi-r3-mini

# Build script
BUILD_SCRIPT=$(cat << 'EOF'
#!/bin/bash

#
PACKAGES=""

# Add Attended Sysupgrade
PACKAGES+=" luci-app-attendedsysupgrade"

# Add PBR (policy based routing)
PACKAGES+=" pbr luci-app-pbr"

# Add QoS over Nftables
PACKAGES+=" nft-qos luci-app-nft-qos"

# Add DDNS service
PACKAGES+=" ddns-scripts ddns-scripts-cloudflare ddns-scripts-services luci-app-ddns"

# Add WireGuard support
PACKAGES+=" kmod-wireguard luci-proto-wireguard wireguard-tools"

# Add Watchcat
PACKAGES+=" luci-app-watchcat watchcat"

# Add AdGuard Home
PACKAGES+=" adguardhome"

# Add mbim, qmi support
PACKAGES+=" kmod-usb-net-cdc-mbim kmod-usb-net-qmi-wwan kmod-usb-serial-option luci-proto-mbim luci-proto-qmi uqmi qmi-utils picocom minicom"

# Add Nut service (Network UPS Tools)
#PACKAGES+=" luci-app-nut nut-server nut-driver-usbhid-ups nut-web-cgi"

# Add Acme support
#PACKAGES+=" acme acme-common acme-acmesh acme-acmesh-dnsapi	luci-app-acme"

# Add Asterisk
#PACKAGES+=" asterisk asterisk-app-system asterisk-bridge-native-rtp asterisk-bridge-simple asterisk-chan-dongle asterisk-codec-alaw asterisk-codec-ulaw asterisk-codec-g722"
#PACKAGES+=" asterisk-codec-gsm asterisk-codec-opus asterisk-format-gsm asterisk-format-ogg-opus asterisk-format-wav asterisk-func-base64 asterisk-func-channel asterisk-func-cut"
#PACKAGES+=" asterisk-func-devstate asterisk-func-dialplan asterisk-func-global asterisk-func-shell asterisk-func-uri asterisk-pbx-spool asterisk-pjsip"
#PACKAGES+=" asterisk-res-rtp-asterisk asterisk-res-rtp-multicast asterisk-res-sorcery asterisk-res-srtp asterisk-sounds"

# Add WOL support
PACKAGES+=" luci-app-wol"

# Add BCP38
PACKAGES+=" luci-app-bcp38 bcp38"

# Add storage support
#PACKAGES+=" kmod-usb-storage block-mount kmod-fs-ext4"

# Add packages to support expanding root partition and filesystem
PACKAGES+=" parted losetup resize2fs e2fsprogs f2fsck mkf2fs"

# Add some extra tools
PACKAGES+=" lm-sensors usbutils pciutils iperf3 iftop"

# Default openwrt packages ppp-mod-pppoeprocd
PACKAGES+=" base-files busybox ca-bundle luci dropbear firewall4 fitblk fstools libc libgcc logd mtd netifd nftables opkg odhcp6c odhcpd-ipv6only bridger"
PACKAGES+=" ppp procd-seccomp procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd e2fsprogs f2fsck mkf2fs mt7988-wo-firmware"
PACKAGES+=" kmod-i2c-mux-pca954x kmod-eeprom-at24 kmod-mt7996-firmware kmod-mt7996-233-firmware kmod-rtc-pcf8563 kmod-crypto-hw-safexcel"
PACKAGES+=" kmod-hwmon-pwmfan kmod-usb3 kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload kmod-phy-aquantia kmod-sfp"

# Replace mbedtls with openssl
PACKAGES+=" -libustream-mbedtls -wpad-basic-mbedtls libustream-openssl wpad-openssl"

# Replace dnsmasq with dnsmasq-full
PACKAGES+=" -dnsmasq dnsmasq-full"

# Exclude odhcp
#PACKAGES+=" -odhcp6c -odhcpd-ipv6only"

#
[ -f "/builder/setup.sh" ] && "/builder/setup.sh"

#
make image PROFILE="${PROFILE}" PACKAGES="${PACKAGES}" FILES="/builder/files"

EOF
)

#
TEMP_DIR="/tmp/${PROFILE}_firmware-${VERSION}-build-root"
OUTPUT_DIR="$(pwd)/output/${PROFILE}/${VERSION}"

#
(mkdir -p "${TEMP_DIR}" "${OUTPUT_DIR}" && chmod 777 "${TEMP_DIR}" "${OUTPUT_DIR}") || exit 1

# Export build script to /tmp
echo "$BUILD_SCRIPT" > "${TEMP_DIR}/build.sh" || exit 1

#
docker run --rm -it --pull always \
    -v "$(pwd)/firmware-files":/builder/files \
    -v "${OUTPUT_DIR}/":/builder/bin/targets/mediatek/filogic \
    -v "${TEMP_DIR}/build.sh":/build.sh \
    -e PROFILE="${PROFILE}" \
    openwrt/imagebuilder:mediatek-filogic-${VERSION} \
    /bin/bash /build.sh

# Remove build script
rm -rf "${TEMP_DIR}" > /dev/null 2> /dev/null

