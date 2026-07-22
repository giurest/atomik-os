# ═══════════════════════════════════════════════════════════════════════════════
#  Atomik OS Server — ujust
#  Host minimale per container (base fedora-bootc).
# ═══════════════════════════════════════════════════════════════════════════════

import? 'common.just'

# [Servizi] Configura Jellyfin in questa VM (mount SMB + quadlet Podman)
jellyfin-setup:
    #!/usr/bin/env bash
    set -euo pipefail

    QUADLET="/etc/containers/systemd/jellyfin.container"
    MOUNT_PATH="/var/mnt/storage"

    echo "┌────────────────────────────────────────────────┐"
    echo "  Jellyfin — setup servizio in questa VM          "
    echo "└────────────────────────────────────────────────┘"
    echo ""
    echo "  Questa ricetta:"
    echo "   1. monta lo storage SMB dal NAS (→ ${MOUNT_PATH})"
    echo "   2. crea il quadlet Podman di Jellyfin"
    echo "   3. avvia il servizio"
    echo ""

    # ── Verifica che Jellyfin non sia già configurato ────────────────────────
    if [[ -f "$QUADLET" ]]; then
        echo "✗ Jellyfin risulta già configurato ($QUADLET)."
        echo "  Rimuovilo prima di rieseguire il setup."
        exit 1
    fi

    # ── 1. Mount dello storage SMB (nome fisso 'storage') ────────────────────
    # Se già montato (da un setup precedente), saltiamo; altrimenti invochiamo
    # smb-system con il nome 'storage' (il resto è interattivo).
    if mountpoint -q "$MOUNT_PATH" 2>/dev/null; then
        echo "✓ Storage già montato in ${MOUNT_PATH}, salto smb-system."
    else
        echo "→ Configuro il mount SMB dello storage..."
        echo "  (rispondi alle domande su share NAS, utente e password)"
        echo ""
        ujust smb-system storage
        # Verifica che il mount sia effettivamente attivo prima di procedere
        if ! mountpoint -q "$MOUNT_PATH" 2>/dev/null; then
            echo "✗ Lo storage non risulta montato in ${MOUNT_PATH}."
            echo "  Setup interrotto: Jellyfin ha bisogno dello storage."
            exit 1
        fi
    fi

    # ── 2. Scrivi il quadlet Jellyfin (fisso) ────────────────────────────────
    echo "→ Creo il quadlet Podman di Jellyfin..."
    sudo mkdir -p /var/lib/jellyfin/config /var/lib/jellyfin/cache

    printf '%s\n' \
        "[Unit]" \
        "Description=Jellyfin Media Server" \
        "After=network-online.target var-mnt-storage.mount" \
        "Wants=network-online.target" \
        "" \
        "[Container]" \
        "Image=docker.io/jellyfin/jellyfin:latest" \
        "PublishPort=8096:8096" \
        "Volume=/var/lib/jellyfin/config:/config:Z" \
        "Volume=/var/lib/jellyfin/cache:/cache:Z" \
        "Volume=/var/mnt/storage:/media" \
        "" \
        "[Service]" \
        "Restart=always" \
        "TimeoutStartSec=900" \
        "" \
        "[Install]" \
        "WantedBy=multi-user.target" \
        | sudo tee "$QUADLET" > /dev/null

    # ── 3. Avvia il servizio ─────────────────────────────────────────────────
    echo "→ Avvio Jellyfin..."
    sudo systemctl daemon-reload
    sudo systemctl start jellyfin.service

    echo ""
    echo "✓ Jellyfin configurato e avviato."
    echo "  Interno VM:  http://$(hostname -I | awk '{print $1}'):8096"
    echo ""
    echo "  Per esporlo sulla LAN, dall'HYPERVISOR:"
    echo "    ujust vm-forward $(hostname) 8096 <porta-host>"
    echo ""
    echo "  Al primo avvio Jellyfin scarica l'immagine: attendi ~1 min,"
    echo "  poi completa la configurazione guidata dal browser."