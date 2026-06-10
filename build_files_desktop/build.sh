#!/bin/bash
set -ouex pipefail

## DNF5 Speedup
sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf 2>/dev/null || true

## Repository DMS + DankLinux
curl -fsSL \
    "https://copr.fedorainfracloud.org/coprs/avengemedia/dms/repo/fedora-44/avengemedia-dms-fedora-44.repo" \
    -o /etc/yum.repos.d/avengemedia-dms.repo
curl -fsSL \
    "https://copr.fedorainfracloud.org/coprs/avengemedia/danklinux/repo/fedora-44/avengemedia-danklinux-fedora-44.repo" \
    -o /etc/yum.repos.d/avengemedia-danklinux.repo

## Flatpak
dnf -y install flatpak

## Pacchetti desktop (da lista)
dnf -y install --skip-unavailable \
    $(grep -v '^#' /ctx/desktop.list | grep -v '^$' | tr '\n' ' ')

## Brave browser RPM
rm -f /opt && mkdir -p /usr/lib/opt && ln -s /usr/lib/opt /opt
dnf -y install dnf-plugins-core
curl -fsSLo /etc/yum.repos.d/brave-browser.repo \
    https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
dnf -y install brave-browser
rm -f /opt && ln -s /var/opt /opt

## Plymouth plugin
dnf -y install plymouth-plugin-script

## Rimuovi repo Terra (chiave GPG mancante, blocca ISO builder)
rm -f /etc/yum.repos.d/terra*.repo

## Pulizia
dnf clean all
