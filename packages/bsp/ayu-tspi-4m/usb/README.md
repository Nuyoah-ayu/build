# TSPI-4M USB support

## Current 6.18 PHY fix

Tracing reproduced an incorrect host PHY suspend with the Hub still connected.
At 125.917 seconds, the driver reported disconnection and powered off the PHY.
The EHCI frame counter then stopped at 0100.
The earlier device tree backup has the same host controller and PHY configuration.

Current 6.18 builds apply `fix-usb2phy-host-connect-irq.patch`.
The patch clears stale connection state on an enabled line-state interrupt.
It also ignores disabled line-state interrupts, matching the Rockchip 6.1 BSP driver.
It preserves normal PHY suspend for disconnected ports.
The patched kernel passed two boot checks on TSPI-4M.
The first boot reported HS online at 64, 125, and 187 seconds.
The second boot ran without dynamic debugging or the temporary tracing service.
Frame counters advanced, the PHY stayed active, and Bluetooth/HID devices remained enumerated.
Hub descriptor reads and Bluetooth discovery start/stop succeeded.
No matching USB timeout appeared during these checks. Longer testing and a complete image reflash remain outstanding.

The older candidate also changed initialization. It remains excluded from default builds.
This new patch does not change initialization. Edge has not received this patch.

## Manual recovery

Current and edge images install `tspi-usb-host-recover`.
Run `tspi-usb-host-recover status` to inspect USB enumeration and EHCI registers.
Run `sudo tspi-usb-host-recover recover` through ADB or the serial console to recover host1.

The tool saves diagnostics and rebinds both controllers sharing the affected PHY.
It briefly disconnects attached keyboards, mice, and Bluetooth.
It refuses recovery when block storage is attached to either target controller.
It leaves the ADB controller running. It does not install an automatic reset service.
Recovery succeeded on a TSPI-4M running 6.18.60-current-rockchip64.

## ADB

Trixie images install the ConfigFS/FunctionFS gadget service for the separate fc000000.usb controller.
Interactive ADB shells enter Bash. The gadget helper supports both FunctionFS readiness interfaces.
The board installs a complete adbd unit without a network-online dependency.
The gadget drop-in retains ConfigFS ordering and USB setup.
ADB can start while Ethernet DHCP remains unavailable.
