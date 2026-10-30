#!/bin/bash
# Runs inside the docker container started by _build.sh. The _build directory
# is mounted read-only at /usr/src/_build, results are written to /out.
set -euo pipefail

TFA_VERSION=v2.15.0
UBOOT_VERSION=v2026.10
UBOOT_DEFCONFIG=nanopi-r76s-rk3576_defconfig
RKBIN_COMMIT=3e288fe814e059dd06833495f845cab04ac20a5c
RKBIN_TPL=bin/rk35/rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.13.bin
RKBIN_TPL_SHA256=f697151bdd09d31bf7a1e49d63796a6a200e81bf8f9a766c2e95c840e88fc0ce
RKBIN_BL31=bin/rk35/rk3576_bl31_v1.25.elf
RKBIN_BL31_SHA256=a709eb309746a46c192405fe95b725a668c20ee05b134478838a69e723bfafb2
FIRMWARE_TAG=20261019
FIRMWARE_FILES=(
  "rtl_nic/rtl8125b-2.fw 529bf1c25c97ff52b401090d00ff89cc22351012336e5a0c9662728a3ee909ef"
)
DTB=rockchip/rk3576-nanopi-r76s.dtb

BUILD=/usr/src/_build
JOBS=$(nproc)

export ARCH=arm64
if [ "$(uname -m)" = "aarch64" ]; then
  export CROSS_COMPILE=
else
  export CROSS_COMPILE=aarch64-linux-gnu-
fi
export KBUILD_BUILD_USER=gokrazy
export KBUILD_BUILD_HOST=docker
export KBUILD_BUILD_TIMESTAMP="Wed Mar  1 20:57:29 UTC 2017"

fetch() { # url dest sha256
  wget -q -O "$2" "$1"
  echo "$3  $2" | sha256sum -c -
}

cd /usr/src

echo "== fetching firmware (linux-firmware $FIRMWARE_TAG)"
for entry in "${FIRMWARE_FILES[@]}"; do
  read -r name sum <<<"$entry"
  mkdir -p "firmware/$(dirname "$name")"
  fetch "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/$name?h=$FIRMWARE_TAG" \
    "firmware/$name" "$sum"
done

echo "== building linux"
url=$(tr -d '[:space:]' < "$BUILD/upstream-url.txt")
wget -q "$url"
tar xf "$(basename "$url")"
srcdir=$(basename "$url" .tar.xz)
while read -r patch; do
  [ -n "$patch" ] || continue
  echo "applying patch $patch"
  patch -d "$srcdir" -p1 < "$BUILD/$patch"
done < "$BUILD/series"

cd "$srcdir"
make defconfig
# Disable all modules so that we end up with a minimal set of (built-in)
# drivers from the config addendum.
make mod2noconfig
cat "$BUILD/config.addendum.txt" >> .config
make olddefconfig

# Fail if any option from the addendum did not end up in the final config
# (e.g. renamed options or unmet dependencies).
missing=0
while IFS= read -r line; do
  case "$line" in CONFIG_*=*) ;; *) continue ;; esac
  opt=${line%%=*}
  val=${line#*=}
  if [ "$val" = "n" ]; then
    grep -q "^$opt=" .config || continue
  else
    grep -qxF "$opt=$val" .config && continue
  fi
  echo "config.addendum.txt: $line not applied (got: $(grep -m1 "^$opt=\|^# $opt is not set" .config || echo unset))" >&2
  missing=1
done < "$BUILD/config.addendum.txt"
# Everything must be built in: gokrazy does not load modules.
if grep "=m$" .config >&2; then
  echo "the options above would be built as modules, set them to y or n in config.addendum.txt" >&2
  missing=1
fi
[ "$missing" -eq 0 ] || exit 1

make -j"$JOBS" Image modules "$DTB"
make INSTALL_MOD_PATH=/tmp/buildresult modules_install
cp arch/arm64/boot/Image /out/vmlinuz
cp "arch/arm64/boot/dts/$DTB" /out/
rm -f /tmp/buildresult/lib/modules/*/build
cp -r /tmp/buildresult/lib /out/
cd /usr/src

echo "== fetching rkbin ($RKBIN_COMMIT)"
fetch "https://raw.githubusercontent.com/rockchip-linux/rkbin/$RKBIN_COMMIT/$RKBIN_TPL" \
  ddr.bin "$RKBIN_TPL_SHA256"

case "$BL31_SOURCE" in
tf-a)
  echo "== building trusted-firmware-a $TFA_VERSION"
  git clone -q --depth=1 -b "$TFA_VERSION" https://github.com/ARM-software/arm-trusted-firmware.git tf-a
  make -C tf-a -j"$JOBS" PLAT=rk3576 bl31
  bl31=/usr/src/tf-a/build/rk3576/release/bl31/bl31.elf
  ;;
rkbin)
  fetch "https://raw.githubusercontent.com/rockchip-linux/rkbin/$RKBIN_COMMIT/$RKBIN_BL31" \
    bl31.elf "$RKBIN_BL31_SHA256"
  bl31=/usr/src/bl31.elf
  ;;
*)
  echo "unknown BL31_SOURCE=$BL31_SOURCE (want tf-a or rkbin)" >&2
  exit 1
  ;;
esac

echo "== building u-boot $UBOOT_VERSION"
git clone -q --depth=1 -b "$UBOOT_VERSION" https://source.denx.de/u-boot/u-boot.git u-boot
cd u-boot
make "$UBOOT_DEFCONFIG"
cat "$BUILD/uboot.config" >> .config
make olddefconfig
make -j"$JOBS" BL31="$bl31" ROCKCHIP_TPL=/usr/src/ddr.bin
cp u-boot-rockchip.bin /out/

chown -R "$HOST_UID:$HOST_GID" /out
