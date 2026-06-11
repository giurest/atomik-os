#!/bin/bash
set -ouex pipefail

## RPMFusion free + nonfree
dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

## Repository DMS + DankLinux (COPR)
dnf copr enable -y avengemedia/dms
dnf copr enable -y avengemedia/danklinux

## Pacchetti desktop
dnf install -y \
    niri \
    dms \
    dms-greeter \
    greetd \
    greetd-selinux \
    fish \
    starship \
    just \
    fastfetch \
    alacritty \
    gnome-keyring \
    gnome-keyring-pam \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    xdg-user-dirs \
    polkit \
    polkit-gnome \
    wireplumber \
    pipewire \
    pipewire-alsa \
    pipewire-pulseaudio \
    pipewire-gstreamer \
    networkmanager \
    nm-connection-editor \
    network-manager-applet \
    NetworkManager-openvpn-gnome \
    wireguard-tools \
    fuse \
    fuse-libs \
    cifs-utils \
    flatpak \
    plymouth-plugin-script \
    bash-completion \
    curl \
    git \
    htop \
    unzip \
    p7zip \
    p7zip-plugins \
    rsync \
    wget

## Pacchetti aggiuntivi da lista
PKGS="$(grep -v '^#' /ctx/desktop.list 2>/dev/null | grep -v '^$' | tr '\n' ' ')"
if [ -n "$PKGS" ]; then
    dnf install -y --skip-unavailable $PKGS
fi

## Brave browser RPM
rm -f /opt && mkdir -p /usr/lib/opt && ln -s /usr/lib/opt /opt
curl -fsSLo /etc/yum.repos.d/brave-browser.repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
dnf install -y brave-browser
rm -f /opt && ln -s /var/opt /opt

## Skel: fish config con starship e no greeting
mkdir -p /etc/skel/.config/fish
printf 'starship init fish | source\nset fish_greeting\n' \
    > /etc/skel/.config/fish/config.fish

## Container policy: consenti immagini Atomik da ghcr.io/giurest
python3 -c "
import json
with open('/etc/containers/policy.json') as f:
    p = json.load(f)
p.setdefault('transports', {}).setdefault('docker', {})['ghcr.io/giurest'] = [{'type': 'insecureAcceptAnything'}]
with open('/etc/containers/policy.json', 'w') as f:
    json.dump(p, f, indent=2)
" 2>/dev/null || true

## Pulizia
dnf clean all
