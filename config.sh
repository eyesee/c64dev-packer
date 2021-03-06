#!/bin/bash

command -v git >/dev/null 2>&1 || { echo "Command 'git' required but it's not installed.  Aborting." >&2; exit 1; }
command -v nproc >/dev/null 2>&1 || { echo "Command 'nproc' from coreutils required but it's not installed.  Aborting." >&2; exit 1; }

. version.sh

export BUILD_BOX_USERNAME="eyesee"
export BUILD_BOX_NAME="c64dev"

export BUILD_BOX_PROVIDER="virtualbox"

export BUILD_BOX_SOURCES="https://github.com/eyesee/c64dev-packer"

export BUILD_PARENT_BOX_USERNAME="foobarlab"
export BUILD_PARENT_BOX_NAME="funtoo-base"
export BUILD_PARENT_BOX_VAGRANTCLOUD_NAME="$BUILD_PARENT_BOX_USERNAME/$BUILD_PARENT_BOX_NAME"

export BUILD_GUEST_TYPE="Gentoo_64"

# default memory/cpus used for final created box:
export BUILD_BOX_CPUS="2"
export BUILD_BOX_MEMORY="2048"

export BUILD_CUSTOM_OVERLAY=true
export BUILD_CUSTOM_OVERLAY_NAME="commodore"
export BUILD_CUSTOM_OVERLAY_URL="https://github.com/eyesee/commodore-overlay.git"
export BUILD_CUSTOM_OVERLAY_BRANCH="main"   # set to 'development' for most current (or 'main' for more stable)

# TODO make finalize step optional, like:
#export BUILD_AUTO_FINALIZE=false  # if 'true' automatically run finalize.sh script

export BUILD_KERNEL=false                 # build a new kernel?
export BUILD_INCLUDE_ANSIBLE=false        # include Ansible build? (already enabled in funtoo-base)
export BUILD_HEADLESS=false               # if false, gui will be shown
# TODO flag for xorg (BUILD_WINDOW_SYSTEM)?

export BUILD_KEEP_MAX_CLOUD_BOXES=1       # set the maximum number of boxes to keep in Vagrant Cloud

# ----------------------------! do not edit below this line !----------------------------

# detect number of system cpus available (always select maximum for best performance)
export BUILD_CPUS=`nproc --all`

let "jobs = $BUILD_CPUS + 1"       # calculate number of jobs (threads + 1)
export BUILD_MAKEOPTS="-j${jobs}"
let "memory = $BUILD_CPUS * 2048"  # recommended 2GB for each cpu
export BUILD_MEMORY="${memory}"

export BUILD_BOX_RELEASE_NOTES="Commodore 64 development environment based on Funtoo Linux. See README in sources for details."     # edit this to reflect actual setup

export BUILD_TIMESTAMP="$(date --iso-8601=seconds)"

BUILD_BOX_DESCRIPTION="$BUILD_BOX_NAME version $BUILD_BOX_VERSION"
if [ -z ${BUILD_TAG+x} ]; then
    # without build tag
    BUILD_BOX_DESCRIPTION="$BUILD_BOX_DESCRIPTION"
else
    # with env var BUILD_TAG set
    # NOTE: for Jenkins builds we got some additional information: BUILD_NUMBER, BUILD_ID, BUILD_DISPLAY_NAME, BUILD_TAG, BUILD_URL
    BUILD_BOX_DESCRIPTION="$BUILD_BOX_DESCRIPTION ($BUILD_TAG)"
fi

export BUILD_GIT_COMMIT_BRANCH=`git rev-parse --abbrev-ref HEAD`
export BUILD_GIT_COMMIT_ID=`git rev-parse HEAD`
export BUILD_GIT_COMMIT_ID_SHORT=`git rev-parse --short HEAD`
export BUILD_GIT_COMMIT_ID_HREF="${BUILD_BOX_SOURCES}/tree/${BUILD_GIT_COMMIT_ID}"

export BUILD_BOX_DESCRIPTION="$BUILD_BOX_RELEASE_NOTES<br><br>$BUILD_BOX_DESCRIPTION<br>created @$BUILD_TIMESTAMP<br><br>Source code: $BUILD_BOX_SOURCES<br>This build is based on branch $BUILD_GIT_COMMIT_BRANCH (commit id <a href=\\\"$BUILD_GIT_COMMIT_ID_HREF\\\">$BUILD_GIT_COMMIT_ID_SHORT</a>)"

export BUILD_OUTPUT_FILE_TEMP="$BUILD_BOX_NAME-$BUILD_BOX_VERSION.tmp.box"
export BUILD_OUTPUT_FILE_INTERMEDIATE="$BUILD_BOX_NAME-$BUILD_BOX_VERSION.raw.box"
export BUILD_OUTPUT_FILE_FINAL="$BUILD_BOX_NAME-$BUILD_BOX_VERSION.box"

# get the latest parent version from Vagrant Cloud API call:
. parent_version.sh

if [ $# -eq 0 ]; then
	echo "Executing $0 ..."
	echo "=== Build settings ============================================================="
	env | grep BUILD_ | sort
	echo "================================================================================"
fi
