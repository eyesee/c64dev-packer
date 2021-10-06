#!/bin/bash -ue
# vim: ts=4 sw=4 et

. ./lib/functions.sh "$*"
require_commands git nproc
set -a

# ----------------------------!  edit settings below  !----------------------------

BUILD_BOX_NAME="c64dev"
BUILD_BOX_USERNAME="eyesee"

BUILD_BOX_PROVIDER="virtualbox"

BUILD_BOX_SOURCES="https://github.com/eyesee/c64dev-packer"

BUILD_PARENT_BOX_USERNAME="foobarlab"
BUILD_PARENT_BOX_NAME="funtoo-base"
BUILD_PARENT_BOX_CLOUD_NAME="$BUILD_PARENT_BOX_USERNAME/$BUILD_PARENT_BOX_NAME"

BUILD_GUEST_TYPE="Gentoo_64"

# default memory/cpus/disk used for final created box:
BUILD_BOX_CPUS="2"
BUILD_BOX_MEMORY="2048"
#BUILD_BOX_DISKSIZE="51200" # resize disk in MB, comment-in to keep existing size

# add a custom overlay?
BUILD_CUSTOM_OVERLAY=true
BUILD_CUSTOM_OVERLAY_NAME="commodore"
BUILD_CUSTOM_OVERLAY_URL="https://github.com/eyesee/commodore-overlay.git"
BUILD_CUSTOM_OVERLAY_BRANCH="development"   # set to 'development' for most current (or 'main' for more stable)

# TODO make finalize step optional, like:
BUILD_AUTO_FINALIZE=false          # if 'true' automatically run finalize.sh script

BUILD_KERNEL=false                 # build a new kernel?
BUILD_HEADLESS=false               # if false, gui will be shown
# TODO flag for xorg (BUILD_WINDOW_SYSTEM)?

# 32 bit chroot for wine
BUILD_CHROOT=true                     # enable chroot (for 32-bit and wine)?
BUILD_CHROOT_ROOT="/chroot32"         # root dir of chroot
BUILD_CHROOT_VERSION_ID="2021-09-19"  # FIXME autodetect by parsing html index
BUILD_CHROOT_ARCH="x86-32bit"         # 32 bit!
BUILD_CHROOT_SUBARCH="i686"           # e.g. 'i686' or 'generic_32'

BUILD_KEEP_MAX_CLOUD_BOXES=1       # set the maximum number of boxes to keep in Vagrant Cloud

# ----------------------------!  do not edit below this line  !----------------------------

. version.sh "$*"   # determine build version

BUILD_CHROOT_STAGE3_FILE="stage3-${BUILD_CHROOT_SUBARCH}-1.4-release-std-${BUILD_CHROOT_VERSION_ID}.tar.xz"
BUILD_CHROOT_STAGE3_URL="https://build.funtoo.org/1.4-release-std/${BUILD_CHROOT_ARCH}/${BUILD_CHROOT_SUBARCH}/${BUILD_CHROOT_VERSION_ID}/${BUILD_CHROOT_STAGE3_FILE}"

# detect number of system cpus available (select half of cpus for best performance)
BUILD_CPUS=$((`nproc --all` / 2))
let "jobs = $BUILD_CPUS + 1"       # calculate number of jobs (threads + 1)
BUILD_MAKEOPTS="-j${jobs}"

# determine ram available (select min and max)
BUILD_MEMORY_MIN=4096 # we want at least 4G ram for our build
# calculate max memory (set to 1/2 of available memory)
BUILD_MEMORY_MAX=$(((`grep MemTotal /proc/meminfo | awk '{print $2}'` / 1024 / 1024 / 2 + 1 ) * 1024))
let "memory = $BUILD_CPUS * 1024"   # calculate 1G ram for each cpu
BUILD_MEMORY="${memory}"
BUILD_MEMORY=$(($BUILD_MEMORY < $BUILD_MEMORY_MIN ? $BUILD_MEMORY_MIN : $BUILD_MEMORY)) # lower limit (min)
BUILD_MEMORY=$(($BUILD_MEMORY > $BUILD_MEMORY_MAX ? $BUILD_MEMORY_MAX : $BUILD_MEMORY)) # upper limit (max)

BUILD_BOX_RELEASE_NOTES="Commodore 64 development environment based on Funtoo Linux. See README in sources for details."     # edit this to reflect actual setup

BUILD_TIMESTAMP="$(date --iso-8601=seconds)"

BUILD_BOX_DESCRIPTION="$BUILD_BOX_NAME version $BUILD_BOX_VERSION"
if [ ! -z ${BUILD_TAG+x} ]; then
    # NOTE: for Jenkins builds we got some additional information: BUILD_NUMBER, BUILD_ID, BUILD_DISPLAY_NAME, BUILD_TAG, BUILD_URL
    BUILD_BOX_DESCRIPTION="$BUILD_BOX_DESCRIPTION ($BUILD_TAG)"
fi

if [[ -f ./build_time && -s build_time ]]; then
    BUILD_RUNTIME=`cat build_time`
    BUILD_RUNTIME_FANCY="Total build runtime was $BUILD_RUNTIME."
else
    BUILD_RUNTIME="unknown"
    BUILD_RUNTIME_FANCY="Total build runtime was not logged."
fi

BUILD_BOX_DESCRIPTION="$BUILD_BOX_RELEASE_NOTES<br><br>$BUILD_BOX_DESCRIPTION<br>created @$BUILD_TIMESTAMP<br>"

# check if in git environment and collect git data (if any)
BUILD_GIT=$(echo `git rev-parse --is-inside-work-tree 2>/dev/null || echo "false"`)
if [ $BUILD_GIT == "true" ]; then
    BUILD_GIT_COMMIT_REPO=`git config --get remote.origin.url`
    BUILD_GIT_COMMIT_BRANCH=`git rev-parse --abbrev-ref HEAD`
    BUILD_GIT_COMMIT_ID=`git rev-parse HEAD`
    BUILD_GIT_COMMIT_ID_SHORT=`git rev-parse --short HEAD`
    BUILD_GIT_COMMIT_ID_HREF="${BUILD_BOX_SOURCES}/tree/${BUILD_GIT_COMMIT_ID}"
    BUILD_GIT_LOCAL_MODIFICATIONS=$(if [ "`git diff --shortstat`" == "" ]; then echo 'false'; else echo 'true'; fi)
    BUILD_BOX_DESCRIPTION="$BUILD_BOX_DESCRIPTION<br>Git repository: $BUILD_GIT_COMMIT_REPO"
    if [ $BUILD_GIT_LOCAL_MODIFICATIONS == "true" ]; then
        BUILD_BOX_DESCRIPTION="$BUILD_BOX_DESCRIPTION<br>This build is in an experimental work-in-progress state. Local modifications have not been committed to Git repository yet.<br>$BUILD_RUNTIME_FANCY"
    else
        BUILD_BOX_DESCRIPTION="$BUILD_BOX_DESCRIPTION<br>This build is based on branch $BUILD_GIT_COMMIT_BRANCH (commit id <a href=\\\"$BUILD_GIT_COMMIT_ID_HREF\\\">$BUILD_GIT_COMMIT_ID_SHORT</a>).<br>$BUILD_RUNTIME_FANCY"
    fi
else
    BUILD_BOX_DESCRIPTION="$BUILD_BOX_DESCRIPTION<br>Origin source code: $BUILD_BOX_SOURCES"
    BUILD_BOX_DESCRIPTION="$BUILD_BOX_DESCRIPTION<br>This build is not version controlled yet.<br>$BUILD_RUNTIME_FANCY"
fi

BUILD_OUTPUT_FILE_TEMP="$BUILD_BOX_NAME.tmp.box"
BUILD_OUTPUT_FILE_INTERMEDIATE="$BUILD_BOX_NAME-$BUILD_BOX_VERSION.raw.box"
BUILD_OUTPUT_FILE="$BUILD_BOX_NAME-$BUILD_BOX_VERSION.box"

BUILD_PARENT_BOX_CHECK=true

# get the latest parent version from Vagrant Cloud API call:
. parent_version.sh "$*"

BUILD_PARENT_BOX_OVF="$HOME/.vagrant.d/boxes/$BUILD_PARENT_BOX_NAME/0/virtualbox/box.ovf"
BUILD_PARENT_BOX_CLOUD_PATHNAME=`echo "$BUILD_PARENT_BOX_CLOUD_NAME" | sed "s|/|-VAGRANTSLASH-|"`
BUILD_PARENT_BOX_CLOUD_OVF="$HOME/.vagrant.d/boxes/$BUILD_PARENT_BOX_CLOUD_PATHNAME/$BUILD_PARENT_BOX_CLOUD_VERSION/virtualbox/box.ovf"
BUILD_PARENT_BOX_CLOUD_VMDK="$HOME/.vagrant.d/boxes/$BUILD_PARENT_BOX_CLOUD_PATHNAME/$BUILD_PARENT_BOX_CLOUD_VERSION/virtualbox/box-disk001.vmdk"
BUILD_PARENT_BOX_CLOUD_VDI="$HOME/.vagrant.d/boxes/$BUILD_PARENT_BOX_CLOUD_PATHNAME/$BUILD_PARENT_BOX_CLOUD_VERSION/virtualbox/box-disk001.vdi"

if [ $# -eq 0 ]; then
    title "BUILD SETTINGS"
    if [ "$ANSI" = "true" ]; then
        env | grep BUILD_ | sort | awk -F"=" '{ printf("'${white}${bold}'%.40s '${default}'%s\n",  $1 "'${dark_grey}'........................................'${default}'" , $2) }'
    else
      env | grep BUILD_ | sort | awk -F"=" '{ printf("%.40s %s\n",  $1 "........................................" , $2) }'
    fi
    title_divider
fi
