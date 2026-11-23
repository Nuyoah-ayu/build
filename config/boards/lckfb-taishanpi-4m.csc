# Rockchip RK3588 octa core 4-32GB RAM SoC HDMI 2xGbE CAN CAN-FD USB3 SATA ES8388
declare -g BOARD_NAME="Taishan Pi 4M"
declare -g BOARD_VENDOR="ayu"
declare -g BOARD_FIRMWARE_INSTALL="-full"
declare -g BOARDFAMILY="rockchip-rk3588"
declare -g INTRODUCED="2026"
declare -g KERNEL_TARGET="vendor,current,edge"
declare -g BOOT_FDT_FILE="rockchip/rk3588-tspi-4m.dtb" # same name for mainline and vendor
declare -g BOOT_SOC="rk3588"
declare -g IMAGE_PARTITION_TABLE="gpt"
declare -g ASOUND_STATE="asound.state.tspi-4m"

# Vendor u-boot is not supported; every target builds mainline u-boot.
declare -g BOOT_SCENARIO="tpl-blob-atf-mainline" # Mainline ATF

function post_family_config__ayu_tspi_4m_use_mainline_uboot() {
	display_alert "$BOARD" "mainline u-boot overrides for $BOARD / $BRANCH" "info"
	if [[ ${BRANCH} == vendor* ]]; then
		declare -g ASOUND_STATE="asound.state.tspi-4m-vendor"
	fi

	declare -g BOOTCONFIG="ayu-tspi-4m-rk3588_defconfig"
	declare -g BOOTDELAY=1
	declare -g BOOTSOURCE="https://github.com/u-boot/u-boot.git"
	declare -g BOOTBRANCH="tag:v2026.01"
	declare -g BOOTPATCHDIR="v2026.01"
	declare -g BOOTDIR="u-boot-${BOARD}"

	declare -g UBOOT_TARGET_MAP="BL31=bl31.elf ROCKCHIP_TPL=${RKBIN_DIR}/${DDR_BLOB};;u-boot-rockchip.bin"
	unset uboot_custom_postprocess write_uboot_platform write_uboot_platform_mtd

	function write_uboot_platform() {
		dd "if=$1/u-boot-rockchip.bin" "of=$2" bs=32k seek=1 conv=notrunc status=none
	}

	declare -g PLYMOUTH="no"
	declare -g SERIALCON="ttyS2"

	# Serial console. The debug UART is uart2 (serial@feb50000). The 8250 driver
	# does NOT number DT ports by ascending address: it probes in node order, so
	# uart1 (feb40000) disabled still occupies index 0, and the map is
	#   feb50000 = ttyS2   feb60000 = ttyS3   feb90000 = ttyS6
	#   febb0000 = ttyS0   febc0000 = ttyS1
	# Verified from the boot log. The rockchip64 family default console=ttyS2
	# is correct for this board, so leave BOOTSCRIPT and SERIALCON at the family
	# value. The vendor DTS disables fiq_debugger and also enables uart2.
	if [[ ${BRANCH} != vendor* ]]; then
		declare -g DEFAULT_CONSOLE="serial"
	fi
}

# "rockchip-common: boot SD card first, then NVMe, then mmc"
# include/configs/rockchip-common.h
# On the TSPI-4M: mmc0 is microSD, mmc1 is eMMC
function pre_config_uboot_target__ayu_tspi_4m_patch_rockchip_common_boot_order() {
	declare -a rockchip_uboot_targets=("mmc0" "nvme" "scsi" "usb" "mmc1" "pxe" "dhcp" "spi")
	display_alert "u-boot for ${BOARD}/${BRANCH}" "u-boot: adjust boot order to '${rockchip_uboot_targets[*]}'" "info"
	sed -i -e "s/#define BOOT_TARGETS.*/#define BOOT_TARGETS \"${rockchip_uboot_targets[*]}\"/" include/configs/rockchip-common.h
	regular_git diff -u include/configs/rockchip-common.h || true
}

# Kernel prints nothing after u-boot's "Starting kernel ..." unless the kernel
# gets earlycon. boot-rockchip64.cmd drops the DTS /chosen/bootargs, so the
# serial port and verbosity must be selected here in armbianEnv.txt.
function image_specific_armbian_env_ready__enable_earlycon() {
	display_alert "$BOARD" "enabling earlycon and debug loglevel on the serial console" "info"
	cat >> ${SDCARD}/boot/armbianEnv.txt <<- 'ARMBIANENV'
	earlycon=on
	verbosity=8
	ARMBIANENV
}

# Enable the drivers the board device tree depends on.
# Array form: applied by armbian_kernel_config_apply_opts_from_arrays, so it is
# safe here (this hook also runs before .config exists).
#
# The family config for rockchip64/current is config/kernel/linux-rockchip64-current.config.
# Already set there (and likewise in the edge config), so no hook entry is needed:
#   SND_SIMPLE_CARD, SOUND, SND_SOC, SND_SOC_ROCKCHIP_I2S_TDM, REGULATOR_RK808,
#   SENSORS_PWM_FAN, LEDS_TRIGGER_HEARTBEAT, TYPEC_FUSB302, CAN_ROCKCHIP_CANFD,
#   TOUCHSCREEN_GOODIX, PCI, PCIEPORTBUS, PCIE_ROCKCHIP_HOST, PCIE_DW_PLAT_HOST,
#   RTW89, RTW89_8852BE, RTW89_8852BTE (RTL8852BE Wi-Fi, pcie2x1l0),
#   MEDIA_SUPPORT=m, VIDEO_IMX208..IMX412, BT, BT_HCIUART, BT_HCIUART_RTL.
#
# The ES8388 codec is matched by drivers/media's sibling sound/soc/codecs/
# es8328-i2c.c via compatible "everest,es8388", and that driver is not in the
# family config, so the DTS audio card stays silent without it.
function custom_kernel_config__ayu_tspi_4m_enable_board_drivers() {
	opts_m+=(
		SND_SOC_ES8328_I2C   # ES8388 codec on i2c4
		SND_SOC_SIMPLE_AMPLIFIER
	)
	if [[ ${BRANCH} == vendor* ]]; then
		opts_y+=(VIDEO_IMX415 VIDEO_ROCKCHIP_CIF VIDEO_ROCKCHIP_ISP)
	fi
}

function custom_kernel_config__ayu_tspi_4m_vendor_rtw89() {
	[[ ${BRANCH} == vendor* ]] || return 0
	local archive="$SRC/packages/bsp/ayu-tspi-4m/rtw89-driver/rtw89-d1fced1b8a741dc9f92b47c69489c24385945f6e.tar.gz"
	local expected="4195581ee75497f96702b4b1f72de65353822b423bbf76e3eb0075106133b86e"
	local compatibility="$SRC/packages/bsp/ayu-tspi-4m/rtw89-driver/rtw89-vendor-compat.patch"
	local compatibility_hash
	local actual
	actual=$(sha256sum "$archive")
	[[ ${actual%% *} == "$expected" ]] || exit_with_error "TSPI rtw89 source checksum mismatch"
	compatibility_hash=$(sha256sum "$compatibility")
	kernel_config_modifying_hashes+=("tspi-rtw89-${expected}-${compatibility_hash%% *}")
	opts_m+=(RTW89)
	[[ -f .config && -n ${kernel_work_dir:-} && $PWD == "$kernel_work_dir" ]] || return 0
	tar -xzf "$archive" --strip-components=1 -C drivers/net/wireless/realtek/rtw89
	patch --batch --fuzz=0 -p1 -d drivers/net/wireless/realtek/rtw89 -i "$compatibility"
}

function extension_prepare_config__ayu_tspi_4m_add_chinese_fonts() {
	[[ ${BUILD_DESKTOP} == yes ]] || return 0
	add_packages_to_image fonts-noto-cjk
}

function extension_prepare_config__ayu_tspi_4m_add_vendor_tools() {
	[[ ${BRANCH} == vendor* ]] || return 0
	add_packages_to_image python3 device-tree-compiler v4l-utils
}

function post_family_tweaks__ayu_tspi_4m_install_display_selector() {
	[[ ${BRANCH} == vendor* ]] || return 0
	install -D -m 755 "$SRC/packages/bsp/ayu-tspi-4m/display/tspi-display" \
		"$SDCARD/usr/local/sbin/tspi-display"
	install -D -m 644 "$SRC/packages/bsp/ayu-tspi-4m/display/README.vendor.md" \
		"$SDCARD/usr/share/doc/tspi-4m/README.vendor.md"
}

function post_family_tweaks__ayu_tspi_4m_keep_display_awake() {
	[[ ${BUILD_DESKTOP} == yes && ${DESKTOP_ENVIRONMENT} == xfce ]] || return 0

	install -D -m 755 "$SRC/packages/bsp/ayu-tspi-4m/display/tspi-keep-awake" \
		"$SDCARD/usr/local/bin/tspi-keep-awake"
	install -D -m 644 "$SRC/packages/bsp/ayu-tspi-4m/display/tspi-keep-awake.desktop" \
		"$SDCARD/etc/xdg/autostart/tspi-keep-awake.desktop"
	install -D -m 644 "$SRC/packages/bsp/ayu-tspi-4m/display/light-locker.desktop" \
		"$SDCARD/etc/xdg/autostart/light-locker.desktop"
	install -D -m 644 "$SRC/packages/bsp/ayu-tspi-4m/display/90-tspi-keep-awake.conf" \
		"$SDCARD/etc/X11/xorg.conf.d/90-tspi-keep-awake.conf"
}

# Friendly names for the ES8388 card and the HDMI outputs.
function post_family_tweaks__ayu_tspi_4m_naming_audios() {
	display_alert "$BOARD" "Naming TSPI-4M audio devices" "info"

	install -D -m 644 "$SRC/packages/bsp/ayu-tspi-4m/audio/90-naming-audios.rules" \
		"$SDCARD/etc/udev/rules.d/90-naming-audios.rules"
	install -D -m 644 "$SRC/packages/bsp/ayu-tspi-4m/audio/51-ayu-tspi-4m-audio-names.conf" \
		"$SDCARD/etc/wireplumber/wireplumber.conf.d/51-ayu-tspi-4m-audio-names.conf"
}
