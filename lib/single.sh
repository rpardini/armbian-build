#!/bin/bash
#
# Copyright (c) 2013-2021 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of the Armbian build script
# https://github.com/armbian/build/

if [[ $(basename "$0") == main.sh ]]; then
	echo "Please use compile.sh to start the build process"
	exit 255
fi

# Libraries include. ONLY source files that contain ONLY functions here.

# shellcheck source=functions/build-single.sh
source "${SRC}"/lib/functions/build-single.sh

# shellcheck source=functions/rootfs.sh
source "${SRC}"/lib/functions/rootfs.sh
# shellcheck source=functions/image.sh
source "${SRC}"/lib/functions/image.sh

# shellcheck source=functions/misc_image.sh
source "${SRC}"/lib/functions/misc_image.sh # helpers for OS image building

# shellcheck source=lib/functions/distro.sh
source "${SRC}"/lib/functions/distro.sh # system specific install

#### REFACTOR ALL THESE
# shellcheck source=functions/desktop.sh
source "${SRC}"/lib/functions/desktop.sh # desktop specific install

# shellcheck source=compilation.sh
source "${SRC}"/lib/compilation.sh # patching and compilation of kernel, uboot, ATF

# shellcheck source=compilation-prepare.sh
source "${SRC}"/lib/compilation-prepare.sh # drivers that are not upstreamed

# shellcheck source=makeboarddeb.sh
source "${SRC}"/lib/makeboarddeb.sh # board support package

# shellcheck source=general.sh
source "${SRC}"/lib/general.sh # general functions

# shellcheck source=chroot-buildpackages.sh
source "${SRC}"/lib/chroot-buildpackages.sh # chroot packages building


## Configuration.
#shellcheck source=functions/misc_configuration.sh
source "${SRC}"/lib/functions/misc_configuration.sh

#shellcheck source=functions/configuration.sh
source "${SRC}"/lib/functions/configuration.sh

# shellcheck source=functions/misc_compile.sh
source "${SRC}"/lib/functions/misc_compile.sh # Misc functions previously found here.
