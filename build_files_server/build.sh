#!/bin/bash
set -ouex pipefail

## ── Atomik OS Server — build script ──────────────────────────────────────────
## Host minimale per container. Nessun ambiente grafico.

## Pacchetti essenziali
dnf install -y \
    podman \
    podman-compose \
    containers-common \
    bash-completion \
    git \
    vim-enhanced \
    nano \
    tmux \
    htop \
    btop \
    curl \
    wget \
    rsync \
    firewalld \
    openssh-server \
    just \
    jq

## ── ujust: comando che punta al justfile server ──────────────────────────────
mkdir -p /usr/share/atomik-server
install -m 0644 /ctx/server-justfile /usr/share/atomik-server/justfile

cat > /usr/bin/ujust << 'UJUST'
#!/bin/bash
# Atomik Server — wrapper ujust
exec just --justfile /usr/share/atomik-server/justfile --working-directory "${HOME:-/root}" "$@"
UJUST
chmod +x /usr/bin/ujust

## ── Shell: bash con colore e autocomplete ────────────────────────────────────
cat > /etc/profile.d/atomik-server.sh << 'PROFILE'
# Atomik Server — shell defaults
if [ -n "${BASH_VERSION:-}" ] && [[ $- == *i* ]]; then
    PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
fi
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias grep='grep --color=auto'
if [[ $- == *i* ]]; then
    echo ""
    echo "  Atomik OS Server — digita 'ujust' per i comandi disponibili"
    echo ""
fi
PROFILE

## ── Servizi abilitati ────────────────────────────────────────────────────────
systemctl enable sshd.service
systemctl enable podman.socket
systemctl enable firewalld.service

## ── Container policy: consenti immagini Atomik da ghcr.io/giurest ─────────────
python3 -c "
import json
with open('/etc/containers/policy.json') as f:
    p = json.load(f)
p.setdefault('transports', {}).setdefault('docker', {})['ghcr.io/giurest'] = [{'type': 'insecureAcceptAnything'}]
with open('/etc/containers/policy.json', 'w') as f:
    json.dump(p, f, indent=2)
" 2>/dev/null || true

## ── Hostname ─────────────────────────────────────────────────────────────────
printf 'atomik-server\n' > /usr/lib/hostname
mkdir -p /usr/lib/tmpfiles.d
printf 'L+ /etc/hostname - - - - /usr/lib/hostname\n' \
    > /usr/lib/tmpfiles.d/atomik-hostname.conf

## ── OS Identity ──────────────────────────────────────────────────────────────
for osr in /etc/os-release /usr/lib/os-release; do
    sed -i 's/^NAME=.*/NAME="Atomik OS"/' "$osr"
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Atomik OS (Server)"/' "$osr"
    sed -i 's/^ID=.*/ID=fedora/' "$osr"
    sed -i '/^LOGO=/d' "$osr"
    echo 'LOGO=atomik-os' >> "$osr"
done

## ── Pulizia ──────────────────────────────────────────────────────────────────
dnf clean all
