#!/bin/bash -uex

if [ -z ${BUILD_RUN:-} ]; then
  echo "This script can not be run directly! Aborting."
  exit 1
fi

if [ -z ${BUILD_CHROOT:-} ]; then
    echo "BUILD_CHROOT was not set. Skipping chroot build."
    exit 0
else
    if [ "$BUILD_CHROOT" = false ]; then
        echo ">>> Skipping chroot build."
        exit 0
    else
        echo ">>> Building chroot in '${BUILD_CHROOT_ROOT}' ..."
    fi
fi

# ---- setup chroot 32bit environment

# see https://www.funtoo.org/32-bit_Chroot
# see https://www.funtoo.org/32_bit_chroot_environment_for_Wine
# see https://wiki.gentoo.org/wiki/Project:AMD64/32-bit_Chroot_Guide#Installation_of_a_32-bit_chroot

# unpack and prepare
sudo mkdir -p "$BUILD_CHROOT_ROOT"
cd "$BUILD_CHROOT_ROOT"
sf_vagrant="`sudo df | grep vagrant | tail -1 | awk '{ print $6 }'`"
sudo tar -xpf $sf_vagrant/"$BUILD_CHROOT_STAGE3_FILE"
sudo mkdir -p var/git/meta-repo
sudo mkdir -p var/cache/portage/distfiles
cat <<'DATA' | sudo tee -a root/.bash_profile
# run env-update on 32-bit chroot login
env-update
. /etc/profile

DATA
cat <<'DATA' | sudo tee -a etc/profile

# ADD THE FOLLOWING LINE TO IDENTIFY YOUR 32-BIT CHROOT ENVIRONMENT
PS1="\[\033[38;5;226m\](32-bit chroot)\[\033[0m\] $PS1"

DATA

# TODO modify make.conf -> binary packages and storage for faster installation

# add chroot32 mount service
# TODO mount /home/vagrant, /vagrant 
cat <<'DATA' | sudo tee -a /etc/init.d/chroot32
#!/sbin/openrc-run

chroot_dir=BUILD_CHROOT_ROOT

depend() {
   need localmount bootmisc
}

start() {
    ebegin "Mounting 32-bit chroot directories"
    mount --rbind /dev "${chroot_dir}/dev" >/dev/null
    mount --rbind /sys "${chroot_dir}/sys" >/dev/null
    mount -t proc none "${chroot_dir}/proc" >/dev/null
    mount -o bind /tmp "${chroot_dir}/tmp" >/dev/null
    mount -o bind,ro /var/git/meta-repo "${chroot_dir}/var/git/meta-repo/" >/dev/null
    mount -o bind,ro /var/git/overlay "${chroot_dir}/var/git/overlay/" >/dev/null
    mount -o bind /var/cache/portage/distfiles "${chroot_dir}/var/cache/portage/distfiles/" >/dev/null
    [[ -d "/vagrant" ]] && mount -o bind /vagrant "${chroot_dir}/vagrant/" >/dev/null
    mount -t tmpfs -o nosuid,nodev,noexec,mode=755 none "${chroot_dir}/run" > /dev/null
    eend $? "An error occured while attempting to mount 32-bit chroot directories."
    ebegin "Copying 32-bit chroot files"
    cp -pf /etc/resolv.conf /etc/passwd /etc/shadow /etc/group \
           /etc/hosts "${chroot_dir}/etc" >/dev/null
           # TODO add /etc/gshadow if needed
    cp -Ppf /etc/localtime "${chroot_dir}/etc" >/dev/null
    eend $? "An error occured while attempting to copy 32-bit chroot files."
}

stop() {
    ebegin "Unmounting 32-bit chroot directories"
    umount -fR "${chroot_dir}/dev" >/dev/null
    umount -fR "${chroot_dir}/sys" >/dev/null
    umount -f "${chroot_dir}/proc" >/dev/null
    umount -f "${chroot_dir}/tmp" >/dev/null
    umount -f "${chroot_dir}/var/git/meta-repo/" >/dev/null
    umount -f "${chroot_dir}/var/git/overlay/" >/dev/null
    umount -f "${chroot_dir}/var/cache/portage/distfiles/" >/dev/null
    umount -f "${chroot_dir}/vagrant/" >/dev/null
    umount -f "${chroot_dir}/run"
    eend $? "An error occured while attempting to unmount 32-bit chroot directories."
}

DATA
sudo sed -i 's/BUILD_CHROOT_ROOT/'"$BUILD_CHROOT_ROOT"'/g' /etc/init.d/chroot32
sudo chmod +x /etc/init.d/chroot32
sudo rc-service chroot32 start
sudo rc-update add chroot32 default 

# setup chroot32 portage stuff
cat <<'DATA' | sudo tee -a etc/portage/package.use
# required for wine-vanilla:
>=sys-auth/consolekit-1.2.1 policykit
>=dev-libs/glib-2.64.6 dbus
>=media-libs/gd-2.3.0 jpeg truetype fontconfig png
DATA

# TODO setup ego profile if needed
sudo linux32 chroot "$BUILD_CHROOT_ROOT" /bin/bash -l -c 'env-update && epro show'

# update world
sudo linux32 chroot "$BUILD_CHROOT_ROOT" /bin/bash -l -c 'emerge -vtuDN --with-bdeps=y @world'

# install software
sudo linux32 chroot "$BUILD_CHROOT_ROOT" /bin/bash -l -c 'emerge -nuvtND --with-bdeps=y \
    app-emulation/wine-vanilla \
    app-admin/eclean-kernel \
'

# uninstall software
sudo linux32 chroot "$BUILD_CHROOT_ROOT" /bin/bash -l -c 'emerge --unmerge -vt \
    sys-kernel/debian-sources \
'

# update world
sudo linux32 chroot "$BUILD_CHROOT_ROOT" /bin/bash -l -c 'emerge -vtuDN --with-bdeps=y @world'

# cleanup
sudo linux32 chroot "$BUILD_CHROOT_ROOT" /bin/bash -l -c 'emerge --depclean && eclean-kernel && rm /usr/src/linux'
