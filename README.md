# gokrazy kernel: upstream Linux for FriendlyElec NanoPi R76S (Rockchip RK3576)

This repository holds a pre-built Linux kernel image, device tree and U-Boot
bootloader for the [FriendlyElec NanoPi R76S](https://wiki.friendlyelec.com/wiki/index.php/NanoPi_R76S)
router, used by the [gokrazy](https://gokrazy.org/) project.

The files in this repository are picked up automatically by
the `gok` tool, so you don’t need to interact with this repository
unless you want to update the kernel to a custom version.

## gokrazy kernel repository map

| repository                         | source         | devices                       |
|------------------------------------|----------------|-------------------------------|
| [gokrazy/kernel.rpi]               | [Raspberry Pi] | Pi 3, Pi 4, Pi 5, Pi Zero 2 W |
| [gokrazy/kernel]                   | [kernel.org]   | Pi 3, Pi 4, Pi Zero 2 W       |
| [gokrazy/kernel.amd64]             | [kernel.org]   | PC x86_64, VMs                |
| [gokrazy/kernel.arm64]             | [kernel.org]   | PC arm64, VMs                 |
| [ascension-association/kernel.q6a] | [Qualcomm]     | Radxa Dragon Q6A              |
| [ascension-association/kernel.r76s]| [kernel.org]   | FriendlyElec NanoPi R76S      |

[Raspberry Pi]: https://github.com/raspberrypi/linux
[kernel.org]: https://kernel.org/
[Qualcomm]: https://github.com/qualcomm-linux/kernel
[gokrazy/kernel.rpi]: https://github.com/gokrazy/kernel.rpi
[gokrazy/kernel]: https://github.com/gokrazy/kernel
[gokrazy/kernel.amd64]: https://github.com/gokrazy/kernel.amd64
[gokrazy/kernel.arm64]: https://github.com/gokrazy/kernel.arm64
[ascension-association/kernel.q6a]: https://github.com/ascension-association/kernel.q6a
[ascension-association/kernel.r76s]: https://github.com/ascension-association/kernel.r76s

## Contents

| file                       | description                                                       |
|----------------------------|-------------------------------------------------------------------|
| `vmlinuz`                  | mainline Linux (`_build/upstream-url.txt`), all drivers built in  |
| `rk3576-nanopi-r76s.dtb`   | mainline device tree, copied to the boot partition                |
| `u-boot-rockchip.bin`      | mainline U-Boot + TF-A BL31 + Rockchip DDR init blob (rkbin)      |
| `lib/modules`              | module metadata (no loadable modules)                             |

Boot flow: the RK3576 boot ROM loads `u-boot-rockchip.bin` from sector 64 of
the microSD card or eMMC. U-Boot then starts gokrazy’s systemd-boot
(`EFI/BOOT/BOOTAA64.EFI`) from the boot partition, which starts `vmlinuz` with
`rk3576-nanopi-r76s.dtb` and the gokrazy kernel command line.

## Usage

Use `gok edit` to add the following entries above the `Hostname` line:

```json
"KernelPackage": "github.com/ascension-association/kernel.r76s",
"FirmwarePackage": "",
"EEPROMPackage": "",
"DeviceType": "rock64",
"SerialConsole": "ttyS0,1500000n8",
```

- `DeviceType: rock64` selects gokrazy’s generic Rockchip disk layout:
  `u-boot-rockchip.bin` is written to sector 64 and the boot partition starts
  at 16 MiB. (There is no dedicated R76S device type in gokrazy yet; the
  layout is identical.)
- `FirmwarePackage` and `EEPROMPackage` are only needed on Raspberry Pis.
- The debug UART (3-pin header) runs at 1500000 baud, like U-Boot.

gokrazy’s DHCP client only configures `eth0`, which is the port labelled
**LAN**. Plug the network cable into LAN, or point DHCP at the WAN port
(`eth1`) with:

```json
"PackageConfig": {
    "github.com/gokrazy/gokrazy/cmd/dhcp": {
        "CommandLineFlags": ["-interface=eth1"]
    }
}
```

Then write the image to a microSD card with `gok overwrite --full /dev/sdX`.

The R76S boot ROM tries eMMC before microSD. If the eMMC already contains a
bootloader (e.g. the factory FriendlyWrt image), it will start first; its
U-Boot normally prefers a bootable microSD card. To boot gokrazy from eMMC,
boot gokrazy (or any Linux) from microSD and write the gokrazy image to
`/dev/mmcblk0`, or use FriendlyElec’s eMMC flashing tools.

## Updating the kernel

Install docker:

```
sudo pacman -S --needed docker
# or: sudo apt-get install docker.io
sudo usermod -aG docker $USER
newgrp docker
```

Clone the kernel git repository:
```
git clone --depth=1 https://github.com/ascension-association/kernel.r76s
cd kernel.r76s
```

Optionally update the Linux version in `_build/upstream-url.txt`, the kernel
config in `_build/config.addendum.txt`, or the U-Boot, TF-A, rkbin and
linux-firmware versions at the top of `_build/indocker.sh`.

And build a new kernel and U-Boot (takes about 10 minutes):
```
(cd _build && ./_build.sh)
```

The build fails if an option from `_build/config.addendum.txt` does not end up
in the final kernel config, e.g. because it was renamed upstream.

BL31 is built from mainline [TF-A](https://github.com/ARM-software/arm-trusted-firmware).
To use Rockchip’s binary BL31 from rkbin instead, run
`(cd _build && BL31_SOURCE=rkbin ./_build.sh)`.

The new files are stored in the working directory. Use `gok add .` to
ensure the next `gok` build will pick up your changed files.

## Not supported (yet)

- On-board Wi-Fi/Bluetooth (RTL8822CS), audio, GPU and video decoding.

## References & Thanks

- [Gokrazy kernel.arm64](https://github.com/gokrazy/kernel.arm64)
- [Ascension Association kernel.q6a](https://github.com/ascension-association/kernel.q6a)
- [U-Boot Rockchip documentation](https://docs.u-boot.org/en/latest/board/rockchip/rockchip.html)
- [FriendlyElec NanoPi R76S wiki](https://wiki.friendlyelec.com/wiki/index.php/NanoPi_R76S)
