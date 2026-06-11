#!/bin/bash
set -ouex pipefail

## RPMFusion e già installato dal desktop base.
## Installiamo solo i pacchetti gaming nativi.

## Steam nativo + gaming tools (RPMFusion gia abilitato su base desktop)
dnf -y install --skip-unavailable \
    steam \
    mangohud \
    gamemode \
    gamemode-devel \
    lutris \
    gamescope

## Pacchetti aggiuntivi da lista
PKGS="$(grep -v '^#' /ctx/puregaming.list 2>/dev/null | grep -v '^$' | tr '\n' ' ')"
if [ -n "$PKGS" ]; then
    dnf -y install --skip-unavailable $PKGS
fi

## Pulizia
dnf clean all
