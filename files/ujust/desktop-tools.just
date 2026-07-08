# ═══════════════════════════════════════════════════════════════════════════════
#  Atomik OS — desktop-tools.just
#  App e strumenti d'uso desktop. Caricato da desktop e puregaming (+ varianti
#  nvidia). NON caricato da hypervisor né server.
#  Importato via `import` dai justfile di variante.
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# App e manutenzione desktop
# ─────────────────────────────────────────────────────────────────────────────

# [Atomik-OS] Benchmark tool 
bench:
    #!/usr/bin/env bash
    SCRIPT=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/giurest/atomik-os/main/tools/atomik-bench -o "$SCRIPT"
    chmod +x "$SCRIPT"
    bash "$SCRIPT"
    rm -f "$SCRIPT"    

# ─────────────────────────────────────────────────────────────────────────────
# GESTORE GIT
# ─────────────────────────────────────────────────────────────────────────────    

# [Manutenzione] Installa WinBoat (Windows app runner via container)
install-winboat:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "→ Verifica prerequisiti..."
    if ! flatpak info com.freerdp.FreeRDP &>/dev/null; then
        echo "→ Installazione FreeRDP 3..."
        flatpak install -y --noninteractive --system flathub com.freerdp.FreeRDP
        echo "✓ FreeRDP installato"
    else
        echo "✓ FreeRDP già presente"
    fi
    echo "→ Scarico l'ultima versione di WinBoat..."
    URL=$(curl -s https://api.github.com/repos/TibixDev/winboat/releases/latest \
        | grep "browser_download_url.*AppImage" \
        | head -1 \
        | cut -d '"' -f 4)
    if [ -z "$URL" ]; then
        echo "✗ Impossibile trovare l'AppImage nelle release."
        exit 1
    fi
    TMPFILE=$(mktemp /tmp/WinBoat-XXXX.AppImage)
    curl -fSL "$URL" -o "$TMPFILE"
    chmod +x "$TMPFILE"
    echo "→ Integrazione con Gear Lever..."
    flatpak run it.mijorus.gearlever --integrate "$TMPFILE"
    rm -f "$TMPFILE"
    echo ""
    echo "✓ WinBoat installato e integrato nel launcher."
    echo "  Prerequisiti: Podman (✓), FreeRDP (✓), KVM abilitato"

# [Manutenzione] Sblocca WinBoat (riavvia il container)
unlock-winboat:
    #!/usr/bin/env bash
    set -euo pipefail
    WINBOAT_DIR="$HOME/.winboat"
    if [ ! -d "$WINBOAT_DIR" ]; then
        echo "✗ WinBoat non trovato in $WINBOAT_DIR"
        exit 1
    fi
    cd "$WINBOAT_DIR"
    echo "→ Arresto container WinBoat..."
    if podman-compose down 2>&1 | tail -3; then
        echo "  ✓ Container fermato"
    else
        echo "  ⚠ Nessun container attivo da fermare"
    fi
    echo ""
    echo "→ Avvio container WinBoat..."
    if podman-compose up -d 2>&1 | tail -5; then
        echo ""
        echo "┌──────────────────────────────────────┐"
        echo "│  ✓ WinBoat pronto                    │"
        echo "│  Stato container:                     │"
        podman ps --filter "name=winboat" 2>/dev/null | tail -1 || true
        echo "└──────────────────────────────────────┘"
    else
        echo "  ✗ Errore nell'avvio del container"
        exit 1
    fi

# [Manutenzione] Applica le regole udev o configurazioni rapide che abbiamo visto prima
fix-solaar:
    @echo "Applicazione permessi Solaar e uinput..."
    sudo curl -sSL https://raw.githubusercontent.com/pwr-Solaar/Solaar/master/rules.d-uinput/42-logitech-unify-permissions.rules -o /etc/udev/rules.d/42-logitech-unify-permissions.rules
    sudo udevadm control --reload-rules && sudo udevadm trigger
    flatpak override --user --device=all io.github.pwr_solaar.solaar    

# [Manutenzione] Powerwash: backup dati essenziali + reset completo del sistema
powerwash:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "┌──────────────────────────────────────┐"
    echo "│  ⚠ POWERWASH — Reset di sistema     │"
    echo "└──────────────────────────────────────┘"
    echo ""
    echo "Flusso di lavoro:"
    echo "  1. Salva SOLO le cartelle scelte su un dispositivo esterno"
    echo "  2. Resetta completamente il sistema (etc, var, flatpak)"
    echo "  3. Al riavvio il sistema sarà come appena installato"
    echo ""
    echo "⚠ TUTTO il resto verrà cancellato: config, app, flatpak, cache."
    echo ""
    read -rp "Continuare? [s/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
        echo "Operazione annullata."
        exit 0
    fi
    USER_HOME="$(realpath "$HOME")"
    USERNAME="$(whoami)"
    echo ""
    echo "── Cartelle da salvare ──"
    echo "Default: Documenti Immagini Video Musica Scaricati"
    read -rp "Cartelle aggiuntive (separate da spazio, vuoto per solo default): " EXTRA
    FOLDERS="Documenti Documents Immagini Pictures Video Videos Musica Music Scaricati Downloads $EXTRA"
    echo ""
    echo "── Destinazione backup ──"
    echo "Dispositivi montati:"
    lsblk -o NAME,SIZE,MOUNTPOINT,FSTYPE | grep -v "loop" | grep -v "^$"
    echo ""
    read -rp "Percorso destinazione (es. /run/media/$USERNAME/USB): " DEST
    if [ ! -d "$DEST" ]; then
        echo "✗ Percorso '$DEST' non trovato."
        exit 1
    fi
    BACKUP_FILE="$DEST/atomik-powerwash-$(date +%Y%m%d-%H%M%S).tar.gz"
    echo ""
    echo "── Creazione backup ──"
    BACKUP_ARGS=""
    for DIR in $FOLDERS; do
        FULL_PATH="$USER_HOME/$DIR"
        if [ -d "$FULL_PATH" ]; then
            echo "  + $DIR"
            BACKUP_ARGS="$BACKUP_ARGS $DIR"
        fi
    done
    if [ -z "$BACKUP_ARGS" ]; then
        echo "✗ Nessuna cartella trovata da salvare."
        exit 1
    fi
    echo ""
    echo "→ Salvataggio in $BACKUP_FILE ..."
    cd "$USER_HOME"
    tar czf "$BACKUP_FILE" $BACKUP_ARGS
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "✓ Backup completato ($BACKUP_SIZE)"
    echo ""
    echo "── Reset sistema ──"
    VARIANT=$(grep "^PRETTY_NAME" /etc/os-release | sed 's/.*(\(.*\)).*/\1/' | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    IMAGE="ghcr.io/giurest/atomik-${VARIANT}:latest"
    echo "Variante rilevata: $VARIANT"
    echo "Immagine: $IMAGE"
    echo ""
    echo "⚠ ULTIMO AVVISO: il sistema verrà resettato al prossimo riavvio."
    echo "  Il backup è stato salvato su: $BACKUP_FILE"
    echo "  SCOLLEGA il dispositivo esterno DOPO il riavvio."
    echo ""
    read -rp "Procedere con il reset? [s/N]: " FINAL
    if [[ ! "$FINAL" =~ ^[sS]$ ]]; then
        echo "Reset annullato. Il backup resta in: $BACKUP_FILE"
        exit 0
    fi
    echo "→ Preparazione reset..."
    sudo /usr/bin/atomik-powerwash-prepare
    echo "→ Switch immagine..."
    sudo bootc switch --mutate-in-place --transport registry "$IMAGE"
    echo ""
    echo "┌──────────────────────────────────────┐"
    echo "│  ✓ Powerwash preparato               │"
    echo "│                                       │"
    echo "│  Al prossimo riavvio:                 │"
    echo "│  • Sistema resettato ai default       │"
    echo "│  • Home pulite                        │"
    echo "│  • Flatpak rimossi                    │"
    echo "│                                       │"
    echo "│  Backup salvato su dispositivo esterno│"
    echo "│                                       │"
    echo "│  Riavvia quando pronto:               │"
    echo "│  sudo systemctl reboot                │"
    echo "└──────────────────────────────────────┘"

