# Atomik OS — ricette specifiche Puregaming (caricato solo su puregaming / puregaming-nvidia)
# Importato via `import?` dal justfile condiviso; il file esiste solo nelle
# immagini puregaming, quindi queste ricette non appaiono sulle altre varianti.

# ─────────────────────────────────────────────────────────────────────────────
# Puregaming — MangoHud
# ─────────────────────────────────────────────────────────────────────────────

# [Manutenzione] Ripristina configurazione MangoHud di default
reset-mangohud:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p ~/.config/MangoHud
    cp /usr/share/atomik/defaults/MangoHud/MangoHud.conf \
       ~/.config/MangoHud/MangoHud.conf
    echo "✓ Configurazione MangoHud ripristinata."

# [Manutenzione] Abilita MangoHud (per gioco o globalmente)
mangohud-enable:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "┌──────────────────────────────────────┐"
    echo "│  MangoHud — Modalità di attivazione  │"
    echo "└──────────────────────────────────────┘"
    echo ""
    echo "  1) Per gioco    — controllo manuale su ogni titolo"
    echo "  2) Globale      — attivo su tutti i giochi automaticamente"
    echo ""
    read -rp "Scelta [1/2]: " CHOICE
    echo ""
    if [[ "$CHOICE" == "1" ]]; then
        echo "── Attivazione per gioco ──"
        echo ""
        echo "  Steam:"
        echo "    → Tasto destro sul gioco → Proprietà"
        echo "    → Opzioni di avvio:"
        echo "      mangohud %command%"
        echo ""
        echo "  Heroic:"
        echo "    → Impostazioni del gioco → Variabili d'ambiente"
        echo "    → Aggiungi: MANGOHUD = 1"
        echo ""
        echo "  Toggle overlay in-game: Shift_R+F12"
    elif [[ "$CHOICE" == "2" ]]; then
        mkdir -p "$HOME/.config/environment.d"
        echo 'MANGOHUD=1' > "$HOME/.config/environment.d/mangohud.conf"
        systemctl --user import-environment MANGOHUD 2>/dev/null || true
        echo "✓ MangoHud attivato globalmente."
        echo "⚠ Riavvia la sessione (logout/login) per applicare."
        echo "⚠ Per giochi Proton usa anche: mangohud %command% nelle opzioni di avvio del singolo gioco che non viene riconosciuto"
        echo ""
        echo "  Heroic:"
        echo "    → Impostazioni → Impostazioni di gioco predefinite"
        echo "    → Variabili d'ambiente → Aggiungi: MANGOHUD = 1"
        echo ""
        echo "  ⚠ Riavvia la sessione (logout/login) per applicare."
        echo "  ⚠ Per giochi Proton usa anche: mangohud %command%"
        echo "  Toggle overlay in-game: Shift_R+F12"
    else
        echo "✗ Scelta non valida."
        exit 1
    fi

# [Manutenzione] Applica 'mangohud %command%' ai giochi Steam installati con launch options vuote
mangohud-steam:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "┌──────────────────────────────────────┐"
    echo "│  MangoHud → Steam launch options     │"
    echo "└──────────────────────────────────────┘"
    echo ""
    echo "Applica 'mangohud %command%' SOLO ai giochi INSTALLATI con launch"
    echo "options vuote. Salta i giochi gia configurati e i tool/runtime Steam."
    echo ""
    STEAM_BASES=(
        "$HOME/.local/share/Steam"
        "$HOME/.steam/steam"
    )
    STEAM_BASE=""
    for d in "${STEAM_BASES[@]}"; do
        if [ -d "$d/steamapps" ] && [ -d "$d/userdata" ]; then
            STEAM_BASE="$d"; break
        fi
    done
    if [ -z "$STEAM_BASE" ]; then
        echo "✗ Nessuna installazione Steam con giochi trovata."
        exit 1
    fi
    echo "→ Steam: $STEAM_BASE"
    INSTALLED_IDS=$(grep -h '"appid"' "$STEAM_BASE"/steamapps/appmanifest_*.acf 2>/dev/null | grep -oP '\d+' | sort -u)
    if [ -z "$INSTALLED_IDS" ]; then
        echo "✗ Nessun gioco installato trovato (appmanifest assenti)."
        exit 1
    fi
    echo "→ Giochi/tool installati: $(echo "$INSTALLED_IDS" | wc -l)"
    if pgrep -x steam >/dev/null || pgrep -f "com.valvesoftware.Steam" >/dev/null; then
        echo ""
        echo "⚠ Steam è in esecuzione. Va chiuso per modificare le launch options."
        read -rp "Chiudere Steam ora? [s/N]: " KILLSTEAM
        if [[ "$KILLSTEAM" =~ ^[sS]$ ]]; then
            steam -shutdown 2>/dev/null || true
            flatpak kill com.valvesoftware.Steam 2>/dev/null || true
            pkill -x steam 2>/dev/null || true
            echo "→ Attendo la chiusura di Steam..."
            sleep 5
        else
            echo "Operazione annullata."; exit 0
        fi
    fi
    # Scarica il parser VDF da main (come ujust bench)
    PARSER=$(mktemp /tmp/mangohud-vdf-XXXX.py)
    trap 'rm -f "$PARSER"' EXIT
    if ! curl -fsSL "https://raw.githubusercontent.com/giurest/atomik-os/main/files/scripts/mangohud-vdf.py" -o "$PARSER"; then
        echo "✗ Impossibile scaricare il parser VDF."
        exit 1
    fi
    REOPEN=0; FOUND=0
    BACKUPS=()
    while IFS= read -r -d '' vdf; do
        FOUND=1
        echo ""
        echo "── Account: $(basename "$(dirname "$(dirname "$vdf")")") ──"
        BACKUP_FILE="${vdf}.$(date +%Y%m%d-%H%M%S).bk"
        cp "$vdf" "$BACKUP_FILE"
        BACKUPS+=("$BACKUP_FILE")
        echo "→ Backup: $BACKUP_FILE"
        echo "$INSTALLED_IDS" | python3 "$PARSER" "$vdf"
        REOPEN=1
    done < <(find "$STEAM_BASE/userdata" -name "localconfig.vdf" -print0 2>/dev/null)
    if [ "$FOUND" -eq 0 ]; then
        echo "✗ Nessun localconfig.vdf trovato."
        exit 1
    fi
    echo ""
    echo "✓ Completato."
    echo ""
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│  RIPRISTINO                                                   │"
    echo "│  Se qualcosa non va, ripristina il VDF dal backup .bk con:    │"
    echo "└──────────────────────────────────────────────────────────────┘"
    for bk in "${BACKUPS[@]}"; do
        orig="${bk%.????????-??????.bk}"
        echo "  cp '$bk' '$orig'"
    done
    echo ""
    if [ "$REOPEN" -eq 1 ]; then
        read -rp "Riaprire Steam ora? [s/N]: " OPENSTEAM
        if [[ "$OPENSTEAM" =~ ^[sS]$ ]]; then
            if command -v steam >/dev/null; then
                nohup steam >/dev/null 2>&1 &
            else
                nohup flatpak run com.valvesoftware.Steam >/dev/null 2>&1 &
            fi
            echo "→ Steam in avvio..."
        fi
    fi

