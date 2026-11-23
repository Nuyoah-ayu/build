# TSPI-4M vendor peripherals

Use `BOARD=tspi-4m BRANCH=vendor`. The vendor kernel is Rockchip 6.1.
The current and edge kernels do not provide this camera pipeline.
These files adapt the supplied Debian reference tree.
Compilation does not establish hardware operation.

## Build

```sh
./compile.sh build BOARD=tspi-4m BRANCH=vendor RELEASE=trixie \
  BUILD_DESKTOP=yes DESKTOP_ENVIRONMENT=xfce DESKTOP_TIER=mid \
  KERNEL_BTF=no KERNEL_CONFIGURE=no
```

Do not pass `KERNEL_TARGET=mainline` for this image.
The boot DTB is `rockchip/rk3588-tspi-4m.dtb`.

## Defaults

The base tree enables dual HDMI output and HDMI input.
It includes four IMX415 capture paths, two Ethernet ports, ES8388 audio, and amplifier control.
GPIO4_PB2 enables the amplifier with a high level. CAN1 remains disabled.
The base also includes USB, Type-C, PCIe, SATA0, CAN0, RTC, fan, LED, IR, GPU, and NPU nodes.
The mini slot defaults to SATA. PCIe3x4 and the separate Wi-Fi PCIe controller remain enabled.
The image includes the RTL8922AE Wi-Fi backport and RTL8922AU Bluetooth firmware and identifiers.
The test board scans access points and Bluetooth devices with these drivers.
The image installs the ADB service on trixie. Vendor ADB works on the test board.
Xfce uses the existing keep-awake settings.

## Display selection

```sh
sudo tspi-display --list
sudo tspi-display hdmi
sudo tspi-display hdmi0 dp0 dsi0-10inch
sudo tspi-display edp1
sudo tspi-display dsi1-10inch
sudo tspi-display default
sudo reboot
```

Each selection replaces the previous TSPI display selection. Include every output that you want enabled.
`default` restores dual HDMI. `off` disables display outputs. HDMI input remains enabled.
Use `--dry-run` to validate a selection without saving it.
Use `--show` to inspect the next boot settings.
The command saves a backup beside `/boot/armbianEnv.txt`.
It preserves other settings and overlays. It validates overlay merging before saving.
Do not mix other display overlays with these selections.
Switching takes effect after reboot. Runtime DRM overlay removal is not supported by this integration.

| Selection | Interface | VOP ports |
| --- | --- | --- |
| hdmi0 | HDMI TX0 | VP0 |
| hdmi1 | HDMI TX1 | VP1 |
| dp0 | DP0, four lanes | VP2 |
| edp1 | Reference DP1 panel, 1368x768, two lanes | VP2 |
| dsi0-10inch / dsi0-3inch | DSI0, 800x1280 / 480x800 | VP3 |
| dsi1-10inch / dsi1-3inch | DSI1, 800x1280 / 480x800 | VP3 |
| hdmi0-8k / hdmi1-8k / dp0-8k | Reference splice configuration | VP0 and VP1 |

The selector rejects shared VOP ports and duplicate interfaces.
DP0 and the DP1 panel cannot share VP2. Both DSI outputs cannot share VP3 in these reference configurations.
DSI selection retains all four CSI paths. Concurrent capture and display require board validation.
DP0 uses all four USB/DP lanes. Its overlay limits the shared USB controller to USB2 speed.
The DP1 panel uses DP1, despite the reference filename containing EDP1.
The reference panel timings and initialization bytes apply only to the matching panels.
The 3.1-inch `my,touch` driver is absent from this SDK. Those touch nodes remain disabled.
The 10.1-inch panels use the available GT9xx driver.
The 8K overlays preserve reference settings. They do not establish 8K compatibility with every monitor.

Without the helper, edit the existing `overlays=` line in `/boot/armbianEnv.txt`.
Preserve non-display overlays, including `panthor-gpu` on modern vendor desktops.
For example, use `overlays=panthor-gpu tspi-4m-display-off tspi-4m-display-edp1`.
Keep exactly one `overlays=` line. Load `tspi-4m-display-off` before the selected outputs.
Remove the TSPI display entries to recover dual HDMI.

## Optional peripherals

Append these names to the existing `overlays=` line. Reboot after changing the line.

| Overlay | Effect |
| --- | --- |
| tspi-4m-mini-pcie | Disable SATA0 and enable PCIe2x1l2 on the shared mini slot |
| tspi-4m-can1 | Enable CAN1 and disable the ES8388 sound card, releasing shared amplifier pins |
| tspi-4m-csi0-ov5695 | Replace the CSI0 IMX415 with the reference OV5695 |

Removing an optional overlay restores its base configuration after reboot.
Do not enable both sensors on CSI0. The base uses IMX415 only.

## Cameras

| Connector | I2C | Reset / power GPIO | Receiver | ISP virtual device |
| --- | --- | --- | --- | --- |
| CSI0 | i2c3, 0x37 | GPIO1_PB5 / GPIO1_PB4 | dcphy0, mipi0 | rkisp1_vir0 |
| CSI1 | i2c2, 0x37 | GPIO1_PB2 / GPIO1_PB3 | dcphy1, mipi1 | rkisp1_vir1 |
| CSI2 | i2c7, 0x37 | GPIO2_PB5 / GPIO2_PB4 | dphy0, mipi2 | rkisp0_vir0 |
| CSI3 | i2c4, 0x37 | GPIO1_PB0 / GPIO1_PB1 | dphy3, mipi4 | rkisp0_vir1 |

All sensors use four lanes. GPIO0_PC5 controls their common supply through one regulator.
The reference module indices are 2, 3, 0, and 1. They differ from connector numbers.
Four virtual devices share two ISPs. This does not guarantee four simultaneous full-rate 4K streams.
Use sensor modules with the reference power design and reset polarity.

```sh
sudo tspi-camera-test --list
sudo tspi-camera-test --frames 90
dmesg | grep -Ei 'imx415|rkcif|rkisp|dphy|hdmirx'
v4l2-ctl --list-devices
media-ctl -p -d /dev/media0
```

The helper discovers connected IMX415 sensors and captures them concurrently through CIF.
The helper tests 3840x2160 RAW10. It reports missing ports separately.
CSI0 and CSI1 each captured 90 frames concurrently at approximately 30 fps on November 14, 2026.
CSI2 and CSI3 were not connected during this test.
Video node numbers depend on probe order.
Verify sensor identification before configuring capture formats and links.
Image quality and automatic exposure require matching Rockchip ISP userspace and sensor tuning files.
This integration does not supply new IQ calibration data.

## Validation status

The board test uses a cached 6.1.115 kernel with the updated DTB and backported modules.
The complete new SDK image still requires a full build and boot test.
Do not install these vendor DTBs or overlays on a current or edge kernel.
The original current boot files remain under /root/tspi-vendor-test/boot-original on the test board.
