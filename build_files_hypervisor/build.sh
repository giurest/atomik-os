#!/bin/bash
set -ouex pipefail

## ═══════════════════════════════════════════════════════════════════════════════
##  Atomik OS Hypervisor — build.sh
##  Base: atomik-desktop (Niri + DMS). Qui aggiungiamo SOLO la virtualizzazione.
##  niri / greetd / ujust / flatpak-base / branding sono ereditati dalla base.
## ═══════════════════════════════════════════════════════════════════════════════

## ── Stack di virtualizzazione ─────────────────────────────────────────────────
## Pacchetti singoli (controllo preciso, filosofia minimale) invece del gruppo
## @virtualization. --skip-unavailable per robustezza sui nomi.
dnf install -y --skip-unavailable \
    libvirt \
    libvirt-daemon-kvm \
    libvirt-daemon-config-network \
    qemu-kvm \
    virt-manager \
    virt-viewer \
    virt-install \
    edk2-ovmf \
    spice-server \
    guestfs-tools \
    bridge-utils \
    socat

## ── Pacchetti aggiuntivi da lista (opzionale) ─────────────────────────────────
PKGS="$( { grep -v '^#' /ctx/hypervisor.list 2>/dev/null || true; } | { grep -v '^$' || true; } | tr '\n' ' ')"
if [ -n "$PKGS" ]; then
    dnf install -y --skip-unavailable $PKGS
fi

## ── Servizi libvirt: socket modulari (approccio moderno Fedora 44) ────────────
## I demoni modulari si attivano on-demand via socket. Più leggeri e robusti
## del vecchio libvirtd monolitico.
systemctl enable virtqemud.socket    2>/dev/null || true
systemctl enable virtnetworkd.socket 2>/dev/null || true
systemctl enable virtstoraged.socket 2>/dev/null || true

## ── Rete NAT default (virbr0) in autostart ────────────────────────────────────
## libvirt-daemon-config-network fornisce la rete 'default'. La rendiamo
## autostart creando il symlink che libvirt controlla al primo avvio.
## (Su bootc /etc persiste; il file di definizione è in /usr/share/libvirt.)
if [ -f /usr/share/libvirt/networks/default.xml ]; then
    mkdir -p /etc/libvirt/qemu/networks/autostart
    ln -sf /etc/libvirt/qemu/networks/default.xml \
           /etc/libvirt/qemu/networks/autostart/default.xml 2>/dev/null || true
fi

## ── Pulizia ───────────────────────────────────────────────────────────────────
dnf clean all
