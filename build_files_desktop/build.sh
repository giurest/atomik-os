#!/bin/bash
set -ouex pipefail

## RPMFusion free (mangohud, gamemode)
dnf -y install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf -y install mangohud gamemode

## Pacchetti aggiuntivi puregaming (da lista)
PKGS="$(grep -v '^#' /ctx/puregaming.list | grep -v '^$' | tr '\n' ' ')"
if [ -n "$PKGS" ]; then
    dnf -y install --skip-unavailable $PKGS
fi

## Pulizia
dnf clean all
