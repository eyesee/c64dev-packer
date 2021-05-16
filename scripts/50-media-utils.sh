#!/bin/bash -uex

if [ -z ${BUILD_RUN:-} ]; then
  echo "This script can not be run directly! Aborting."
  exit 1
fi

# ---- Image utilities

# TODO
#sudo emerge -nuvtND --with-bdeps=y \
#    media-gfx/gimp \
#    media-gfx/imagemagick

# ---- Video utilities    

# TODO
#sudo emerge -nuvtND --with-bdeps=y \
#    media-video/ffmpeg

# ---- Sound players

sudo emerge -nuvtND --with-bdeps=y \
    media-sound/sidplay \
    media-sound/sidplayfp

# ---- Sync packages

sf_vagrant="`sudo df | grep vagrant | tail -1 | awk '{ print $6 }'`"
sudo rsync -urv /var/cache/portage/packages/* $sf_vagrant/packages/
