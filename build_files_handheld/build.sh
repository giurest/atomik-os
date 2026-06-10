#!/bin/bash
set -ouex pipefail

## Gamescope + seatd (sessione alternativa nel greeter)
dnf -y install \
    gamescope \
    seatd \
    xorg-x11-server-Xwayland

## Rimuovi repo Terra
rm -f /etc/yum.repos.d/terra*.repo

## Pulizia
dnf clean all
