function extension_prepare_config__prepare_localmodconfig() {
	# If defined, ${KERNEL_CONFIG_FROM_LSMOD} can contain a list of lsmods to apply to the kernel.
	# to get a file for this run 'lsmod > my_machine.lsmod' and then put it in userpatches/lsmod/
	export KERNEL_CONFIG_FROM_LSMOD="${KERNEL_CONFIG_FROM_LSMOD:-}"
}

# This needs much more love than this. can be used to make "light" versions of kernels, that compile 3x-5x faster or more
function custom_kernel_config__apply_localmodconfig() {

	if [[ "a${KERNEL_CONFIG_FROM_LSMOD}a" != "aa" ]]; then
		# @TODO: multiple make no sense. run make localmodconfig out of the loop. concat lsmods maybe
		for one_lsmod_ref in ${KERNEL_CONFIG_FROM_LSMOD}; do
			local lsmod_file="${SRC}/userpatches/lsmod/${one_lsmod_ref}.lsmod"
			display_alert "localmodconfig with lsmod" "$one_lsmod_ref" "info"
			eval CCACHE_BASEDIR="$(pwd)" env PATH="${toolchain}:${PATH}" \
				'make ARCH=$ARCHITECTURE CROSS_COMPILE="$CCACHE $KERNEL_COMPILER" LSMOD=${lsmod_file} localmodconfig'
		done
	fi
}
