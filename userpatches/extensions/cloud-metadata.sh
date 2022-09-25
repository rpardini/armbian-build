enable_extension "cloud-serialconsole"

function user_config__metadata_cloud_config_common() {
	display_alert "Configuring cloud-init for real metadata" "cloud-metadata: common" "info"
	EXTRA_IMAGE_SUFFIXES+=("-metadata") # global array # For the 'real cloud' version, we skip the c-i config and add a version to the build
	declare -g SKIP_CLOUD_INIT_CONFIG="yes"
}
