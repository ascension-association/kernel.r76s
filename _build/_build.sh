#!/bin/bash
# Builds the Linux kernel, device tree and U-Boot for the NanoPi R76S in a
# docker container and copies the results into the repository root.
set -euo pipefail

cd "$(dirname "$0")"

image=gokrazy-kernel-r76s
docker build -t "$image" .

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

if docker run --rm \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -e BL31_SOURCE="${BL31_SOURCE:-tf-a}" \
  -v "$PWD:/usr/src/_build:ro" \
  -v "$out:/out" \
  "$image" /usr/src/_build/indocker.sh; then
  rm -rf ../lib ../*.dtb
  cp -r "$out"/lib "$out"/vmlinuz "$out"/*.dtb "$out"/u-boot-rockchip.bin ..
  echo "New vmlinuz kernel, device tree and u-boot-rockchip.bin created successfully!"
else
  echo "Build error - see output above for more details." >&2
  exit 1
fi
