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
## Nota: molti pacchetti sono già in Silverblue (NetworkManager, pipewire, ecc.)
## polkit-gnome non esiste su F43, networkmanager va scritto NetworkManager
## starship non è nei repo Fedora, si installa separatamente
dnf install -y --skip-unavailable \
    niri \
    dms \
    dms-greeter \
    greetd \
    greetd-selinux \
    fish \
    just \
    fastfetch \
    alacritty \
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

## Pacchetti aggiuntivi da lista (opzionale)
PKGS="$(grep -v '^#' /ctx/desktop.list 2>/dev/null | grep -v '^$' | tr '\n' ' ')"
if [ -n "$PKGS" ]; then
    dnf install -y --skip-unavailable $PKGS
fi

## Starship prompt (non nei repo Fedora, binario ufficiale)
curl -fsSL https://starship.rs/install.sh | sh -s -- --yes -b /usr/bin

## Brave browser RPM
rm -f /opt && mkdir -p /usr/lib/opt && ln -s /usr/lib/opt /opt
curl -fsSLo /etc/yum.repos.d/brave-browser.repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
dnf install -y brave-browser
rm -f /opt && ln -s /var/opt /opt

## Fish config: starship + no greeting per nuovi utenti
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
