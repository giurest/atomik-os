# ═══════════════════════════════════════════════════════════════════════════════
#  Atomik OS — environment.just
#  Funzioni dell'ambiente d'uso grafico. Caricato dalle 5 varianti con server
#  grafico (desktop, desktop-nvidia, puregaming, puregaming-nvidia, hypervisor).
#  Importato via `import` dai justfile di variante. NON caricato dal server.
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# Ambiente desktop / aspetto
# ─────────────────────────────────────────────────────────────────────────────

# [Manutenzione] Ripristina TUTTA la configurazione desktop (Niri + DMS + Fastfetch + Wallpaper)
reset-desktop:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "⚠ Questa operazione sovrascriverà le configurazioni attuali di:"
    echo "  • Niri (config.kdl, binds, window rules)"
    echo "  • DMS (settings.json)"
    echo "  • Fastfetch"
    echo "  • Wallpaper"
    echo ""
    echo "Le personalizzazioni correnti andranno perse."
    echo ""
    read -rp "Continuare? [s/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
        echo "Operazione annullata."
        exit 0
    fi
    echo ""
    echo "→ Reset configurazione Niri..."
    mkdir -p ~/.config/niri/dms
    cp /usr/share/atomik/defaults/niri/config.kdl ~/.config/niri/config.kdl
    cp /usr/share/atomik/defaults/niri/dms/binds.kdl ~/.config/niri/dms/binds.kdl
    cp /usr/share/atomik/defaults/niri/dms/windowrules.kdl ~/.config/niri/dms/windowrules.kdl
    echo "→ Reset configurazione DMS..."
    mkdir -p ~/.config/DankMaterialShell
    cp /usr/share/atomik/defaults/DankMaterialShell/settings.json ~/.config/DankMaterialShell/settings.json
    cp /usr/share/atomik/defaults/DankMaterialShell/plugin_settings.json ~/.config/DankMaterialShell/plugin_settings.json
    echo "→ Installazione plugin DankActions..."
    dms plugins install dankActions 2>/dev/null || true
    echo "→ Reset Fastfetch..."
    mkdir -p ~/.config/fastfetch
    ln -sf /etc/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc
    ln -sf /etc/fastfetch/atomik-logo.txt ~/.config/fastfetch/atomik-logo.txt
    echo "→ Reset Wallpaper..."
    dms ipc call wallpaper set /usr/share/backgrounds/atomik/atomik-wall.jpg 2>/dev/null || true
    echo ""
    echo "✓ Configurazione desktop ripristinata."
    echo "  Riavvia DMS o fai logout/login per applicare."

# [Manutenzione] Reimposta il wallpaper di Atomik
set-wallpaper:
    dms ipc call wallpaper set /usr/share/backgrounds/atomik/atomik-wall.jpg
    @echo "✓ Wallpaper Atomik impostato."

# [Manutenzione] Ripristina la configurazione fastfetch di default
reset-fastfetch:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p ~/.config/fastfetch
    ln -sf /etc/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc
    ln -sf /etc/fastfetch/atomik-logo.txt ~/.config/fastfetch/atomik-logo.txt
    echo "✓ Configurazione fastfetch ripristinata."

# [Manutenzione] Applica impostazioni di default di Alacritty - fish - starship
reapply-fish:
    sudo rm -f /var/lib/atomik-fish-setup-done
    sudo systemctl restart atomik-fish-setup
    @echo "✓ Fish setup riapplicato"

# ─────────────────────────────────────────────────────────────────────────────
# Accesso remoto (SSH)
# ─────────────────────────────────────────────────────────────────────────────

# [Rete] Abilita e avvia il server SSH
sshd:
    #!/usr/bin/env bash
    if systemctl is-active --quiet sshd.service; then
        echo "✓ sshd è già attivo"
    else
        echo "→ Attivazione sshd..."
        sudo systemctl enable --now sshd.service
        echo "✓ sshd attivato e avviato"
    fi
    echo ""
    USER=$(whoami)
    IP=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)
    if [ -n "$IP" ]; then
        echo "┌──────────────────────────────────────┐"
        echo "│  Connettiti con:                     │"
        echo "│  ssh ${USER}@${IP}"
        echo "└──────────────────────────────────────┘"
    else
        echo "⚠ Nessun indirizzo IP trovato"
    fi
    echo ""
    echo "Stato: $(systemctl is-active sshd.service) | Abilitato al boot: $(systemctl is-enabled sshd.service)"

# [Rete] Disabilita e ferma il server SSH
sshd-off:
    #!/usr/bin/env bash
    if systemctl is-active --quiet sshd.service; then
        echo "→ Arresto sshd..."
        sudo systemctl disable --now sshd.service
        echo "✓ sshd disattivato e fermato"
    else
        echo "✓ sshd è già spento"
        if systemctl is-enabled --quiet sshd.service 2>/dev/null; then
            echo "→ Rimuovo avvio automatico..."
            sudo systemctl disable sshd.service
            echo "✓ Rimosso dal boot"
        fi
    fi

