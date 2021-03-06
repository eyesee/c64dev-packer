#!/bin/bash -e

if [ -z ${BUILD_RUN:-} ]; then
  echo "This script can not be run directly! Aborting."
  exit 1
fi

if [ -z ${SCRIPTS:-} ]; then
  SCRIPTS=.
fi

chmod +x $SCRIPTS/scripts/*.sh

for script in \
  10-prepare \
  20-kernel \
  30-system-update \
  40-graphic-utils \
  50-audio-utils \
  60-toolchain \
  70-emulators \
  90-postprocess \
  99-cleanup
do
  echo "==============================================================================="
  echo " >>> Running $script.sh"
  echo "==============================================================================="
  "$SCRIPTS/scripts/$script.sh"
  printf "\n\n"
done

echo "All done."
