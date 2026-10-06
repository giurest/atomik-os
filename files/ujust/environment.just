# ═══════════════════════════════════════════════════════════════════════════════
#  Atomik OS — environment.just
#  Funzioni dell'ambiente d'uso grafico. Caricato dalle 5 varianti con server
#  grafico (desktop, desktop-nvidia, puregaming, puregaming-nvidia, hypervisor).
#  Importato via `import` dai justfile di variante. NON caricato dal server.
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# Ambiente desktop / aspetto
# ─────────────────────────────────────────────────────────────────────────────

# [Manutenzione] Ripristina la configurazione fastfetch di default
reset-fastfetch:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p ~/.config/fastfetch
    ln -sf /etc/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc
    ln -sf /etc/fastfetch/atomik-logo.txt ~/.config/fastfetch/atomik-logo.txt
    echo "✓ Configurazione fastfetch ripristinata."

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

