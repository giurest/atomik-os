#!/bin/bash
set -ouex pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Atomik OS — build variante Desktop (base Fedora Kinoite / KDE Plasma)
# Sostituisce lo stack niri/DMS/greetd con Plasma nativo.
# Principio: RIUTILIZZO MASSIMO della base Kinoite (Konsole, Dolphin, Breeze,
# widget Plasma nativi, Spectacle) — non si reinstallano tool GTK/niri.
# ═══════════════════════════════════════════════════════════════════════════════

## RPMFusion free + nonfree
dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

## Pacchetti desktop
## NOTA: rispetto alla variante niri/Silverblue, RIMOSSI:
##   - COPR avengemedia/dms + danklinux (niri/DMS)
##   - niri, dms, dms-greeter, greetd, greetd-selinux (stack compositor/greeter)
##   - alacritty (→ Konsole, base Kinoite)
##   - grim, slurp, wf-recorder, swayidle (screenshot/idle wayland → Spectacle nativo)
##   - network-manager-applet (→ widget rete Plasma nativo)
## Kinoite fornisce già: Plasma, KWin, SDDM, Konsole, Dolphin, Breeze, Spectacle,
## controllo audio/rete nativi, pipewire, NetworkManager.
dnf install -y --skip-unavailable \
    fish \
    just \
    fastfetch \
    plymouth-plugin-script \
    wireguard-tools \
    NetworkManager-openvpn \
    fuse \
    fuse-libs \
    cifs-utils \
    flatpak \
    bash-completion \
    curl \
    git \
    htop \
    unzip \
    p7zip \
    p7zip-plugins \
    rsync \
    wget \
    virt-viewer

## Pacchetti aggiuntivi da lista (opzionale)
PKGS="$(grep -v '^#' /ctx/desktop.list 2>/dev/null | grep -v '^$' | tr '\n' ' ')"
if [ -n "$PKGS" ]; then
    dnf install -y --skip-unavailable $PKGS
fi

## Starship prompt (binario ufficiale, versione fissata + verifica SHA256)
## Aggiornamento: nuova versione da github.com/starship/starship/releases,
## checksum dal file starship-x86_64-unknown-linux-musl.tar.gz.sha256 della release.
STARSHIP_VERSION="1.27.0"
STARSHIP_SHA256="10c8eb4cb3b761d9bf59ea828444c2dab36c900b7d69a69e08814b286969df89"
curl -fsSLo /tmp/starship.tar.gz \
    "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-musl.tar.gz"
echo "${STARSHIP_SHA256}  /tmp/starship.tar.gz" | sha256sum -c -
tar -xzf /tmp/starship.tar.gz -C /usr/bin starship
rm -f /tmp/starship.tar.gz

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
