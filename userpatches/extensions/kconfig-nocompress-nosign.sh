# @TODO: internalize this to core?
# @TODO: use similar to set LOCALVERSION, might be more efficient than passing via cmdline

function armbian_kernel_config__disable_module_compression() {
	display_alert "Disabling module compression" "MODULE_COMPRESS" "warn"
	kernel_config_set_n CONFIG_MODULE_COMPRESS_XZ
	kernel_config_set_n CONFIG_MODULE_COMPRESS_ZSTD
	kernel_config_set_n CONFIG_MODULE_COMPRESS_GZIP
	kernel_config_set_y CONFIG_MODULE_COMPRESS_NONE
	display_alert "Disabling module compression" "DONE MODULE_COMPRESS" "warn"
}

function armbian_kernel_config__disable_module_signing() {
	display_alert "Disabling module signing" "CONFIG_MODULE_SIG" "warn"
	kernel_config_set_n CONFIG_SECURITY_LOCKDOWN_LSM
	kernel_config_set_n CONFIG_MODULE_SIG
	display_alert "Disabling module signing" "DONE CONFIG_MODULE_SIG" "warn"
}

function DISABLED_armbian_kernel_config__enable_module_compression() {
	display_alert "Enabling module compression" "MODULE_COMPRESS" "warn"
	kernel_config_set_n CONFIG_MODULE_COMPRESS_XZ
	kernel_config_set_y CONFIG_MODULE_COMPRESS_ZSTD
	kernel_config_set_n CONFIG_MODULE_COMPRESS_GZIP
	kernel_config_set_n CONFIG_MODULE_COMPRESS_NONE
	display_alert "Enabling module compression" "DONE MODULE_COMPRESS" "warn"
}

function kernel_config_set_m() {
	declare module="$1"
	display_alert "Enabling kernel module" "${module}=m" "debug"
	run_host_command_logged ./scripts/config --module "$module"
}

function kernel_config_set_y() {
	declare config="$1"
	display_alert "Enabling kernel config/built-in" "${config}=y" "debug"
	run_host_command_logged ./scripts/config --enable "${config}"
}

function kernel_config_set_n() {
	declare config="$1"
	display_alert "Disabling kernel config/module" "${config}=n" "debug"
	run_host_command_logged ./scripts/config --disable "${config}"
}
