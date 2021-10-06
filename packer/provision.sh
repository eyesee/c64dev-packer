#!/bin/bash -ue
# vim: ts=2 sw=2 et

if [ -z ${BUILD_RUN:-} ]; then
  echo "This script can not be run directly! Aborting."
  exit 1
fi

if [ -z ${scripts:-} ]; then
  SCRIPTS=.
fi

chmod +x ${scripts}/scripts/*.sh

for script in \
  10-prepare \
  20-kernel \
  30-system-update \
  40-base \
  50-media-utils \
  60-toolchain \
  70-emulators \
  80-chroot \
  90-postprocess \
  99-cleanup
do
  echo "==============================================================================="
  echo " >>> Running $script.sh"
  echo "==============================================================================="
  "$scripts/scripts/$script.sh"
  printf "\n\n"
done

echo "All done."
