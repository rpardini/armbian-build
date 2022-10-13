#!/usr/bin/env bash

# @TODO: env passing. people (err... me) pass ENV vars to ./compile.sh so they're active before cmdline options are parsed.
# we'd need to re-pass like (sudo --preserve-env) envs to Docker, or find a solution. or just rewrite overwrites in armbian itself to run super-early & then again where it is now.

# @TODO: integrate logs?

#

#set -o pipefail  # trace ERR through pipes - will be enabled "soon"
#set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable - one day will be enabled
set -e
set -o errtrace # trace ERR through - enabled
set -o errexit  ## set -e : exit the script if any statement returns a non-true return value - enabled
# Important, go read http://mywiki.wooledge.org/BashFAQ/105 NOW!

SRC="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
cd "${SRC}" || exit

# check for whitespace in ${SRC} and exit for safety reasons
grep -q "[[:space:]]" <<< "${SRC}" && {
	echo "\"${SRC}\" contains whitespace. Not supported. Aborting." >&2
	exit 1
}

# Sanity check.
if [[ ! -f "${SRC}"/lib/single.sh ]]; then
	echo "Error: missing build directory structure"
	echo "Please clone the full repository https://github.com/armbian/build/"
	exit 255
fi

# shellcheck source=lib/single.sh
source "${SRC}"/lib/single.sh



# 'main'
export SHOW_LOG=${SHOW_LOG:-yes}
export SHOW_DEBUG=${SHOW_DEBUG:-yes}
export SHOW_COMMAND=${SHOW_COMMAND:-yes}
export SHOW_TRAPS=${SHOW_TRAPS:-yes}
# initialize logging variables.
logging_init

# initialize the traps  
traps_init

# create a temp dir where we'll do our business; follow the Armbian convention so we can re-use their functions
export DEST="${SRC}/output/docker-stuff" # required by do_with_logging, not really used
export LOGDIR="${DEST}"
mkdir -p "${DEST}" "${LOGDIR}"

LOG_SECTION="docker_cli_prepare" do_with_logging docker_cli_prepare "$@"

if [[ "${DOCKERFILE_GENERATE_ONLY}" == "yes" ]]; then
	display_alert "Dockerfile generated" "exiting" "info"
	exit 0
fi

LOG_SECTION="docker_cli_build_dockerfile" do_with_logging docker_cli_build_dockerfile "$@"
LOG_SECTION="docker_cli_prepare_launch" do_with_logging docker_cli_prepare_launch "$@"
docker_cli_launch "$@"
