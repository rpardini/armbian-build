#!/bin/bash

declare -a COMBO_RELEASES=(
	"bullseye" "bookworm" "trixie" "forky" "sid"
	"jammy" "noble"
)
declare -a COMBO_ARCHES=("arm64" "armhf" "amd64" "riscv64")

declare -a COMBO_VARIATIONS=(
	"BUILD_MINIMAL=no"                                                                                 #  default cli build
	"BUILD_MINIMAL=yes"                                                                # minimal build
	"BUILD_MINIMAL=no BUILD_DESKTOP=yes DESKTOP_APPGROUPS_SELECTED= DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base DESKTOP_ENVIRONMENT=xfce"  # xfce desktop
	"BUILD_MINIMAL=no BUILD_DESKTOP=yes DESKTOP_APPGROUPS_SELECTED= DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base DESKTOP_ENVIRONMENT=gnome" # gnome desktop
)

rm -rf output

for release in "${COMBO_RELEASES[@]}"; do
	for arch in "${COMBO_ARCHES[@]}"; do
		for variation in "${COMBO_VARIATIONS[@]}"; do
			echo "=== Building aggregation info for RELEASE=${release} ARCH=${arch} VARIATION='${variation}' ==="
			# shellcheck disable=SC2086
			./compile.sh RELEASE="${release}" ARCH="${arch}" ${variation} AGGREGATION_INFO_ONLY="yes" ARTIFACT_IGNORE_CACHE=yes rootfs
		done
	done
done

tree output/info || true
