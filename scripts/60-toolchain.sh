#!/bin/bash -uex

if [ -z ${BUILD_RUN:-} ]; then
  echo "This script can not be run directly! Aborting."
  exit 1
fi

# ---- Assembler

sudo emerge -nuvtND --with-bdeps=y \
    dev-embedded/cc65 \
    dev-embedded/xa

# ---- Packer

sudo emerge -nuvtND --with-bdeps=y \
    app-arch/pucrunch \
    app-arch-exomizer

# TODO add exomizer

# ---- Sync packages

sf_vagrant="`sudo df | grep vagrant | tail -1 | awk '{ print $6 }'`"
sudo rsync -urv /var/cache/portage/packages/* $sf_vagrant/packages/
