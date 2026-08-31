#!/bin/bash
set -ouex pipefail

## ═══════════════════════════════════════════════════════════════════════════════
##  Atomik OS Hypervisor — build.sh
##  Base: atomik-desktop (KDE Plasma / Kinoite). Qui aggiungiamo SOLO la virtualizzazione.
##  Plasma / SDDM / ujust / flatpak-base / branding sono ereditati dalla base.
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
    socat \
    cockpit \
    cockpit-machines \
    cockpit-storaged \
    cockpit-selinux \
    fail2ban \
    fail2ban-firewalld

## ── Pacchetti aggiuntivi da lista (opzionale) ─────────────────────────────────
PKGS="$( { grep -v '^#' /ctx/hypervisor.list 2>/dev/null || true; } | { grep -v '^$' || true; } | tr '\n' ' ')"
if [ -n "$PKGS" ]; then
    dnf install -y --skip-unavailable $PKGS
fi

## ── fail2ban: protezione brute-force SSH ─────────────────────────────────────
mkdir -p /etc/fail2ban/jail.d
printf '%s\n' \
    "[sshd]" \
    "enabled = true" \
    "backend = systemd" \
    "journalmatch = _SYSTEMD_UNIT=sshd.service + _COMM=sshd" \
    "maxretry = 5" \
    "bantime = 1h" \
    "findtime = 10m" \
    > /etc/fail2ban/jail.d/sshd.local

printf '%s\n' \
    "[Definition]" \
    "logtarget = SYSTEMD-JOURNAL" \
    "dbfile = :memory:" \
    > /etc/fail2ban/fail2ban.local

systemctl enable fail2ban

## ── Servizi libvirt: socket modulari (approccio moderno Fedora 44) ────────────
## I demoni modulari si attivano on-demand via socket. Più leggeri e robusti
## del vecchio libvirtd monolitico.
systemctl enable virtqemud.socket    2>/dev/null || true
systemctl enable virtnetworkd.socket 2>/dev/null || true
systemctl enable virtstoraged.socket 2>/dev/null || true

## ── Cockpit: socket attivo, MA non esposto in LAN ────────────────────────────
## Il pacchetto cockpit aggiunge il servizio alla zona firewall di default:
## lo rimuoviamo. L'accesso avviene solo via SSH tunnel (vedi docs/hypervisor.md).
systemctl enable cockpit.socket
firewall-offline-cmd --remove-service=cockpit 2>/dev/null || true
firewall-offline-cmd --add-port=9090/tcp
firewall-offline-cmd --remove-service=cockpit/a firewall-offline-cmd --add-port=9090/tcp
firewall-offline-cmd --add-port=9090/tcp

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
