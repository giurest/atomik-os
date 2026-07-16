# ═══════════════════════════════════════════════════════════════════════════════
#  Atomik OS — common.just
#  Ricette universali condivise da TUTTE le varianti (desktop, puregaming,
#  hypervisor, server). Importato via `import` dai justfile di ogni variante.
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# Gestione utenti
# ─────────────────────────────────────────────────────────────────────────────

# [Gestione utenti] Crea un nuovo utente con home e shell, aggiunto al gruppo wheel (sudo)
create-user username="":
    #!/usr/bin/env bash
    set -euo pipefail
    USERNAME="{{username}}"
    if [[ -z "$USERNAME" ]]; then
        read -rp "Nome utente da creare: " USERNAME
    fi
    if [[ -z "$USERNAME" ]]; then
        echo "Errore: nome utente vuoto."
        exit 1
    fi
    if id "$USERNAME" &>/dev/null; then
        echo "L'utente '$USERNAME' esiste già."
        exit 1
    fi
    sudo useradd -m -G wheel -s /usr/bin/bash "$USERNAME"
    echo "Imposta la password per '$USERNAME':"
    sudo passwd "$USERNAME"
    echo "✓ Utente '$USERNAME' creato e aggiunto al gruppo wheel."

# [Gestione utenti] Elimina un utente esistente (opzionalmente con la sua home)
delete-user username="":
    #!/usr/bin/env bash
    set -euo pipefail
    USERNAME="{{username}}"
    if [[ -z "$USERNAME" ]]; then
        read -rp "Nome utente da eliminare: " USERNAME
    fi
    if [[ -z "$USERNAME" ]]; then
        echo "Errore: nome utente vuoto."
        exit 1
    fi
    if ! id "$USERNAME" &>/dev/null; then
        echo "L'utente '$USERNAME' non esiste."
        exit 1
    fi
    read -rp "Eliminare anche la home directory? [s/N]: " DELHOME
    if [[ "$DELHOME" =~ ^[sS]$ ]]; then
        sudo userdel -r "$USERNAME"
        echo "✓ Utente '$USERNAME' e home eliminati."
    else
        sudo userdel "$USERNAME"
        echo "✓ Utente '$USERNAME' eliminato (home conservata)."
    fi

# [Gestione utenti] Cambia la password di un utente
passwd-user username="":
    #!/usr/bin/env bash
    set -euo pipefail
    USERNAME="{{username}}"
    if [[ -z "$USERNAME" ]]; then
        read -rp "Utente di cui cambiare la password: " USERNAME
    fi
    sudo passwd "$USERNAME"

# [Gestione utenti] Aggiungi o rimuovi i privilegi sudo (gruppo wheel) per un utente
toggle-sudo username="":
    #!/usr/bin/env bash
    set -euo pipefail
    USERNAME="{{username}}"
    if [[ -z "$USERNAME" ]]; then
        read -rp "Utente: " USERNAME
    fi
    if id -nG "$USERNAME" | grep -qw wheel; then
        sudo gpasswd -d "$USERNAME" wheel
        echo "✓ Privilegi sudo rimossi da '$USERNAME'."
    else
        sudo gpasswd -a "$USERNAME" wheel
        echo "✓ Privilegi sudo concessi a '$USERNAME'."
    fi

# [Gestione utenti] Elenca gli utenti umani del sistema (UID >= 1000)
list-users:
    #!/usr/bin/env bash
    awk -F: '$3 >= 1000 && $3 < 65534 { print $1 " (uid " $3 ")" }' /etc/passwd

# ─────────────────────────────────────────────────────────────────────────────
# Sistema (bootc)
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Sistema (bootc)
# ─────────────────────────────────────────────────────────────────────────────

# [Atomik-OS] Aggiorna il sistema
update:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "$HOME/.local/share/atomik"
    echo "→ Salvataggio stato pacchetti..."
    rpm -qa --queryformat '%{NAME}.%{ARCH} %{EVR}\n' | grep -v '^gpg-pubkey' | sort > "$HOME/.local/share/atomik/rpms-before.txt"    
    echo "→ Controllo aggiornamenti..."
    sudo bootc upgrade
    echo ""
    echo "✓ Aggiornamento scaricato."
    echo "  Dopo il riavvio esegui: ujust changelog"
    echo ""
    read -rp "Riavviare ora? [s/N]: " R
    if [[ "$R" =~ ^[sS]$ ]]; then
        sudo systemctl reboot
    fi

# [Atomik-OS] Mostra cosa è cambiato dopo l'ultimo aggiornamento
changelog:
    /usr/bin/atomik-changelog    

# [Atomik-OS] Mostra lo stato corrente dell'immagine bootc
status:
    sudo bootc status

# [Atomik-OS] Torna alla versione precedente del sistema (rollback)
rollback:
    @echo "Rollback alla versione precedente…"
    sudo bootc rollback
    @echo "✓ Riavvia per applicare il rollback."

# [Atomik-OS] Riavvia il sistema
reboot:
    #!/usr/bin/env bash
    set -euo pipefail
    read -rp "Riavviare il sistema ora? [s/N]: " R
    if [[ "$R" =~ ^[sS]$ ]]; then
        sudo systemctl reboot
    else
        echo "Annullato."
    fi

# ─────────────────────────────────────────────────────────────────────────────
# Git
# ─────────────────────────────────────────────────────────────────────────────

# [GIT] Configura Git e chiavi SSH per un repo
git-config:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "┌──────────────────────────────────────┐"
    echo "│  Configurazione Git + SSH            │"
    echo "└──────────────────────────────────────┘"
    echo ""
    CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "")
    CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
    if [ -n "$CURRENT_NAME" ]; then
        echo "  Configurazione attuale:"
        echo "  Nome:  $CURRENT_NAME"
        echo "  Email: $CURRENT_EMAIL"
        echo ""
        read -rp "Riconfigurare? [s/N]: " RECONF
        if [[ ! "$RECONF" =~ ^[sS]$ ]]; then
            echo ""
        else
            read -rp "Nome e cognome: " GIT_NAME
            read -rp "Email: " GIT_EMAIL
            git config --global user.name "$GIT_NAME"
            git config --global user.email "$GIT_EMAIL"
            echo "✓ Identità aggiornata"
            echo ""
        fi
    else
        read -rp "Nome e cognome: " GIT_NAME
        read -rp "Email: " GIT_EMAIL
        git config --global user.name "$GIT_NAME"
        git config --global user.email "$GIT_EMAIL"
        echo "✓ Identità configurata"
        echo ""
    fi
    echo "── Chiave SSH ──"
    if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
        echo "  ✓ Chiave esistente:"
        cat "$HOME/.ssh/id_ed25519.pub"
    else
        read -rp "Generare una nuova chiave SSH? [s/N]: " GENKEY
        if [[ "$GENKEY" =~ ^[sS]$ ]]; then
            EMAIL=$(git config --global user.email)
            ssh-keygen -t ed25519 -C "$EMAIL" -f "$HOME/.ssh/id_ed25519"
            eval "$(ssh-agent -s)" > /dev/null
            ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null
            echo ""
            echo "✓ Chiave generata. Copia questa su GitHub/GitLab:"
            echo ""
            cat "$HOME/.ssh/id_ed25519.pub"
        fi
    fi
    echo ""
    echo "── Clona repository ──"
    read -rp "URL repository da clonare (vuoto per saltare): " REPO_URL
    if [ -n "$REPO_URL" ]; then
        read -rp "Cartella destinazione (default: ~/code): " CODE_DIR
        CODE_DIR="${CODE_DIR:-$HOME/code}"
        mkdir -p "$CODE_DIR"
        cd "$CODE_DIR"
        git clone "$REPO_URL"
        echo "✓ Repository clonato in $CODE_DIR"
    fi

# [GIT] Workflow git rapido: fetch, pull, add, commit, push
git project="":
    #!/usr/bin/env bash
    set -euo pipefail
    PROJECT="{{project}}"
    if [ -z "$PROJECT" ]; then
        read -rp "Nome progetto (cartella in ~/code/): " PROJECT
    fi
    if [ -z "$PROJECT" ]; then
        echo "✗ Nome progetto vuoto."
        exit 1
    fi
    PROJECT_DIR="$HOME/code/$PROJECT"
    if [ ! -d "$PROJECT_DIR/.git" ]; then
        echo "✗ '$PROJECT_DIR' non è un repository git."
        exit 1
    fi
    cd "$PROJECT_DIR"
    BRANCH=$(git branch --show-current)
    echo "┌──────────────────────────────────────┐"
    echo "│  Git: $PROJECT ($BRANCH)"
    echo "└──────────────────────────────────────┘"
    echo ""
    echo "→ Fetch..."
    git fetch --all --prune
    echo ""
    echo "→ Pull..."
    git pull --rebase 2>/dev/null || git pull
    echo ""
    echo "→ Stato:"
    git status --short
    echo ""
    CHANGES=$(git status --porcelain)
    if [ -z "$CHANGES" ]; then
        echo "✓ Nessuna modifica da committare."
        exit 0
    fi
    echo "── File modificati ──"
    git diff --stat
    echo ""
    git status --short
    echo ""
    read -rp "Aggiungere tutto e committare? [s/N]: " DO_COMMIT
    if [[ ! "$DO_COMMIT" =~ ^[sS]$ ]]; then
        echo "Operazione annullata."
        exit 0
    fi
    echo ""
    read -rp "Messaggio commit: " COMMIT_MSG
    if [ -z "$COMMIT_MSG" ]; then
        echo "✗ Messaggio vuoto, commit annullato."
        exit 1
    fi
    git add -A
    git commit -m "$COMMIT_MSG"
    echo ""
    read -rp "Push su $BRANCH? [s/N]: " DO_PUSH
    if [[ "$DO_PUSH" =~ ^[sS]$ ]]; then
        git push origin "$BRANCH"
        echo ""
        echo "✓ Push completato su $BRANCH"
    else
        echo "✓ Commit locale, push saltato."
    fi

# ─────────────────────────────────────────────────────────────────────────────
# Manutenzione
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# Rete
# ─────────────────────────────────────────────────────────────────────────────

# [Rete] Mostra configurazione eth/wifi e stato della connessione
network-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "═══ Dispositivi ═══"
    nmcli -f DEVICE,TYPE,STATE,CONNECTION device status
    echo ""
    echo "═══ Connessioni attive ═══"
    for c in $(nmcli -t -f NAME connection show --active); do
        echo "── $c ──"
        nmcli -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS connection show "$c" \
            | grep -vE 'IP4\.(ADDRESS|GATEWAY|DNS)\[?[0-9]*\]?:\s*--' || true
        echo ""
    done
    echo "═══ Routing ═══"
    ip route show | grep '^default' || echo "(nessun default gateway)"

# [Rete] Rende una connessione statica (IP, subnet, gateway, DNS)
network-static:
    #!/usr/bin/env bash
    set -euo pipefail
    # Selezione connessione (menu numerato)
    mapfile -t CONNS < <(nmcli -t -f NAME,TYPE,DEVICE connection show --active \
        | awk -F: '$2 ~ /ethernet|wireless/ {print $1" ("$3")"}')
    [ "${#CONNS[@]}" -eq 0 ] && { echo "Nessuna connessione attiva."; exit 1; }
    echo "Connessioni attive:"
    for i in "${!CONNS[@]}"; do echo "  $((i+1))) ${CONNS[$i]}"; done
    read -rp "Scegli [1-${#CONNS[@]}]: " choice
    [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#CONNS[@]}" ] \
        || { echo "Scelta non valida."; exit 1; }
    CONN="${CONNS[$((choice-1))]% (*}"
    echo "Connessione selezionata: $CONN"
    # Parametri statici
    read -rp "Indirizzo IP (es. 192.168.1.50): " IP
    read -rp "Subnet prefix (es. 24): " PREFIX
    read -rp "Gateway (es. 192.168.1.1): " GW
    read -rp "DNS primario (es. 192.168.1.1): " DNS1
    read -rp "DNS secondario (vuoto per nessuno): " DNS2
    DNS="$DNS1"; [ -n "$DNS2" ] && DNS="$DNS1,$DNS2"
    sudo nmcli connection modify "$CONN" \
        ipv4.method manual \
        ipv4.addresses "$IP/$PREFIX" \
        ipv4.gateway "$GW" \
        ipv4.dns "$DNS" \
        ipv4.ignore-auto-dns yes
    echo "✓ Configurazione statica impostata su '$CONN'."
    read -rp "Riapplico ora (down/up)? [s/N]: " ans
    if [[ "$ans" =~ ^[sS]$ ]]; then
        sudo nmcli connection down "$CONN" || true
        sudo nmcli connection up "$CONN"
        echo "✓ Connessione riapplicata."
    else
        echo "ℹ Applica con: sudo nmcli connection up \"$CONN\""
    fi

# [Rete] Riporta una connessione in DHCP completo (azzera override)
network-dhcp:
    #!/usr/bin/env bash
    set -euo pipefail
    mapfile -t CONNS < <(nmcli -t -f NAME,TYPE,DEVICE connection show --active \
        | awk -F: '$2 ~ /ethernet|wireless/ {print $1" ("$3")"}')
    [ "${#CONNS[@]}" -eq 0 ] && { echo "Nessuna connessione attiva."; exit 1; }
    echo "Connessioni attive:"
    for i in "${!CONNS[@]}"; do echo "  $((i+1))) ${CONNS[$i]}"; done
    read -rp "Scegli [1-${#CONNS[@]}]: " choice
    [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#CONNS[@]}" ] \
        || { echo "Scelta non valida."; exit 1; }
    CONN="${CONNS[$((choice-1))]% (*}"
    echo "Connessione selezionata: $CONN"
    sudo nmcli connection modify "$CONN" \
        ipv4.method auto \
        ipv4.addresses "" \
        ipv4.gateway "" \
        ipv4.dns "" \
        ipv4.routes "" \
        ipv4.ignore-auto-dns no
    echo "✓ '$CONN' riportata in DHCP completo."
    read -rp "Riapplico ora (down/up)? [s/N]: " ans
    if [[ "$ans" =~ ^[sS]$ ]]; then
        sudo nmcli connection down "$CONN" || true
        sudo nmcli connection up "$CONN"
        echo "✓ Connessione riapplicata."
    else
        echo "ℹ Applica con: sudo nmcli connection up \"$CONN\""
    fi

# [Rete] Cambia i DNS mantenendo IP/gateway da DHCP (override selettivo)
network-dns:
    #!/usr/bin/env bash
    set -euo pipefail
    mapfile -t CONNS < <(nmcli -t -f NAME,TYPE,DEVICE connection show --active \
        | awk -F: '$2 ~ /ethernet|wireless/ {print $1" ("$3")"}')
    [ "${#CONNS[@]}" -eq 0 ] && { echo "Nessuna connessione attiva."; exit 1; }
    echo "Connessioni attive:"
    for i in "${!CONNS[@]}"; do echo "  $((i+1))) ${CONNS[$i]}"; done
    read -rp "Scegli [1-${#CONNS[@]}]: " choice
    [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#CONNS[@]}" ] \
        || { echo "Scelta non valida."; exit 1; }
    CONN="${CONNS[$((choice-1))]% (*}"
    echo "Connessione selezionata: $CONN"
    read -rp "DNS primario (es. 192.168.1.1): " DNS1
    read -rp "DNS secondario (vuoto per nessuno): " DNS2
    DNS="$DNS1"; [ -n "$DNS2" ] && DNS="$DNS1,$DNS2"
    sudo nmcli connection modify "$CONN" \
        ipv4.dns "$DNS" \
        ipv4.ignore-auto-dns yes
    echo "✓ DNS impostati su '$CONN': $DNS (override DHCP)."
    read -rp "Riapplico ora (down/up)? [s/N]: " ans
    if [[ "$ans" =~ ^[sS]$ ]]; then
        sudo nmcli connection down "$CONN" || true
        sudo nmcli connection up "$CONN"
        echo "✓ Connessione riapplicata."
    else
        echo "ℹ Applica con: sudo nmcli connection up \"$CONN\""
    fi

# [Rete] Verifica connettività (gateway, internet, DNS)
network-ping:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "═══ Gateway ═══"
    GW=$(ip route show default | awk '/default/ {print $3; exit}')
    if [ -n "$GW" ]; then
        ping -c 3 -W 2 "$GW" && echo "✓ Gateway raggiungibile" || echo "✗ Gateway irraggiungibile"
    else
        echo "✗ Nessun default gateway configurato"
    fi
    echo ""
    echo "═══ Internet (1.1.1.1) ═══"
    ping -c 3 -W 2 1.1.1.1 && echo "✓ Internet raggiungibile" || echo "✗ Internet irraggiungibile"
    echo ""
    echo "═══ DNS (risoluzione) ═══"
    if getent hosts cloudflare.com >/dev/null; then
        echo "✓ Risoluzione DNS funzionante"
    else
        echo "✗ Risoluzione DNS fallita"
    fi

# [Rete] Riavvia NetworkManager e ripristina le connessioni
network-reset:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "⚠ Questo riavvia NetworkManager e tutte le connessioni."
    read -rp "Procedo? [s/N]: " ans
    [[ "$ans" =~ ^[sS]$ ]] || { echo "Annullato."; exit 0; }
    sudo systemctl restart NetworkManager
    sleep 2
    echo "✓ NetworkManager riavviato."
    nmcli -f DEVICE,STATE,CONNECTION device status

# ── SMB / Condivisioni di rete ───────────────────────────────────────────────
 

# ─────────────────────────────────────────────────────────────────────────────
# SMB / Condivisioni di rete
# ─────────────────────────────────────────────────────────────────────────────

# [Rete] Crea una connessione SMB persistente (NAS, PC Windows)
smb-connect:
    #!/usr/bin/env bash
    set -euo pipefail
    USER_HOME="$(realpath "$HOME")"
    USER_UID=$(id -u)
    CRED_DIR="/etc/atomik-smb"

    echo "┌──────────────────────────────────────┐"
    echo "│  Connessione SMB / Condivisione rete │"
    echo "└──────────────────────────────────────┘"
    echo ""
    read -rp "Nome cartella contenitore (es. nas, shares): " CONTAINER
    [[ -z "$CONTAINER" ]] && { echo "✗ Nome contenitore vuoto."; exit 1; }
    mkdir -p "$USER_HOME/$CONTAINER"

    read -rp "Nome connessione (es. server1, backup, media): " CONNECTION
    [[ -z "$CONNECTION" ]] && { echo "✗ Nome connessione vuoto."; exit 1; }

    MOUNT_PATH="$USER_HOME/$CONTAINER/$CONNECTION"
    if mountpoint -q "$MOUNT_PATH" 2>/dev/null; then
        echo "✗ '$MOUNT_PATH' è già un mount attivo."
        exit 1
    fi
    mkdir -p "$MOUNT_PATH"

    read -rp "Descrizione (es. NAS Ufficio): " DESCRIPTION
    read -rp "Percorso remoto (es. //192.168.178.100/dati): " REMOTE_PATH
    read -rp "Utente SMB: " SMB_USER
    read -srp "Password SMB: " SMB_PASS
    echo ""

    UNIT_NAME=$(systemd-escape --path "$MOUNT_PATH")
    CRED_FILE="${CRED_DIR}/${UNIT_NAME}.cred"
    UNIT_MOUNT="/etc/systemd/system/${UNIT_NAME}.mount"
    UNIT_AUTO="/etc/systemd/system/${UNIT_NAME}.automount"

    echo ""
    echo "→ Configurazione:"
    echo "  Mount:  $MOUNT_PATH"
    echo "  Remote: $REMOTE_PATH"
    echo "  Utente: $SMB_USER"
    echo "  Unit:   $UNIT_NAME"
    echo "  Cred:   $CRED_FILE (0600)"
    echo ""
    read -rp "Confermi? [s/N]: " CONFIRM
    [[ ! "$CONFIRM" =~ ^[sS]$ ]] && { echo "Operazione annullata."; exit 0; }

    # Pulizia in caso di errore: niente unit o credenziali orfane
    cleanup_on_error() {
        echo ""
        echo "✗ Errore durante la creazione: rimuovo i file parziali."
        sudo rm -f "$UNIT_MOUNT" "$UNIT_AUTO" "$CRED_FILE"
        sudo systemctl daemon-reload || true
    }
    trap cleanup_on_error ERR

    # Credenziali in file separato (0600): mai in chiaro nella unit
    sudo mkdir -p "$CRED_DIR"
    sudo chmod 700 "$CRED_DIR"
    printf 'username=%s\npassword=%s\n' "$SMB_USER" "$SMB_PASS" \
        | sudo tee "$CRED_FILE" > /dev/null
    sudo chmod 600 "$CRED_FILE"

    printf '%s\n' \
        "[Unit]" \
        "Description=${DESCRIPTION}" \
        "" \
        "[Mount]" \
        "What=${REMOTE_PATH}" \
        "Where=${MOUNT_PATH}" \
        "Type=cifs" \
        "Options=rw,credentials=${CRED_FILE},uid=${USER_UID},file_mode=0700,dir_mode=0700" \
        "DirectoryMode=0700" \
        "" \
        "[Install]" \
        "WantedBy=multi-user.target" \
        | sudo tee "$UNIT_MOUNT" > /dev/null

    printf '%s\n' \
        "[Unit]" \
        "Description=${DESCRIPTION} (automount)" \
        "" \
        "[Automount]" \
        "Where=${MOUNT_PATH}" \
        "TimeoutIdleSec=60" \
        "" \
        "[Install]" \
        "WantedBy=multi-user.target" \
        | sudo tee "$UNIT_AUTO" > /dev/null

    sudo systemctl daemon-reload
    sudo systemctl enable --now "${UNIT_NAME}.automount"
    trap - ERR

    echo ""
    echo "✓ Connessione '$CONNECTION' creata e attiva."
    echo "  Accedi a: $MOUNT_PATH"
    echo "  Si monta automaticamente al primo accesso."

# [Rete] Rimuovi una connessione SMB
smb-disconnect:
    #!/usr/bin/env bash
    set -euo pipefail
    USER_HOME="$(realpath "$HOME")"
    echo "┌──────────────────────────────────────┐"
    echo "│  Rimozione connessione SMB           │"
    echo "└──────────────────────────────────────┘"
    echo ""
    read -rp "Nome cartella contenitore (es. nas): " CONTAINER
    read -rp "Nome connessione da rimuovere (es. server1): " CONNECTION
    MOUNT_PATH="$USER_HOME/$CONTAINER/$CONNECTION"
    UNIT_NAME=$(systemd-escape --path "$MOUNT_PATH")
    if [[ ! -f "/etc/systemd/system/${UNIT_NAME}.mount" ]]; then
        echo "✗ Nessuna connessione trovata per '$MOUNT_PATH'."
        exit 1
    fi
    echo ""
    echo "⚠ Verrà rimossa la connessione:"
    echo "  Mount: $MOUNT_PATH"
    echo "  Unit:  $UNIT_NAME"
    echo ""
    read -rp "Confermi? [s/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
        echo "Operazione annullata."
        exit 0
    fi
    CRED_FILE="/etc/atomik-smb/${UNIT_NAME}.cred"
    sudo systemctl disable --now "${UNIT_NAME}.automount" 2>/dev/null || true
    sudo systemctl stop "${UNIT_NAME}.mount" 2>/dev/null || true
    sudo rm -f "/etc/systemd/system/${UNIT_NAME}.mount"
    sudo rm -f "/etc/systemd/system/${UNIT_NAME}.automount"
    sudo rm -f "$CRED_FILE"                    # rimuove anche le credenziali, evita file orfani
    sudo systemctl daemon-reload
    #rmdir "$MOUNT_PATH" 2>/dev/null || true

    #echo "✓ Connessione rimossa."
    read -rp "Eliminare anche la cartella '$MOUNT_PATH'? [s/N]: " DELFOLDER
    if [[ "$DELFOLDER" =~ ^[sS]$ ]]; then
        rm -rf "$MOUNT_PATH"
        echo "✓ Cartella rimossa."
    fi
    echo "✓ Connessione '$CONNECTION' rimossa."
 

# [Rete] Elenca le connessioni SMB attive
smb-list:
    #!/usr/bin/env bash
    echo "┌──────────────────────────────────────┐"
    echo "│  Connessioni SMB attive              │"
    echo "└──────────────────────────────────────┘"
    echo ""
    FOUND=0
    for f in /etc/systemd/system/var-*.mount; do
        [ -f "$f" ] || continue
        UNIT=$(basename "$f")
        WHERE=$(grep "^Where=" "$f" | cut -d= -f2)
        WHAT=$(grep "^What=" "$f" | cut -d= -f2)
        STATUS=$(systemctl is-active "${UNIT%.mount}.automount" 2>/dev/null || echo "inattivo")
        echo "  $WHERE → $WHAT [$STATUS]"
        FOUND=1
    done
    if [ "$FOUND" -eq 0 ]; then
        echo "  Nessuna connessione SMB configurata."
    fi


# [Rete] Crea un mount SMB di sistema accessibile ai container (servizi)
smb-system:
    #!/usr/bin/env bash
    set -euo pipefail
    CRED_DIR="/etc/atomik-smb"

    echo "┌────────────────────────────────────────────────┐"
    echo "│  Mount SMB di sistema (per servizi/container)   │"
    echo "└────────────────────────────────────────────────┘"
    echo ""
    echo "  A differenza di 'smb-connect' (mount personale nella home),"
    echo "  questo crea un mount in /mnt accessibile ai container."
    echo ""

    read -rp "Nome del mount (es. media) → /mnt/<nome>: " NAME
    [[ -z "$NAME" ]] && { echo "✗ Nome vuoto."; exit 1; }

    # bootc/ostree: /mnt è un symlink verso /var/mnt.
    # systemd rifiuta i mount su path non canonici → risolviamo il path reale.
    sudo mkdir -p "/mnt/${NAME}"
    MOUNT_PATH="$(readlink -f "/mnt/${NAME}")"
    if mountpoint -q "$MOUNT_PATH" 2>/dev/null; then
        echo "✗ '$MOUNT_PATH' è già un mount attivo."
        exit 1
    fi

    read -rp "Descrizione (es. Media NAS): " DESCRIPTION
    read -rp "Percorso remoto (es. //192.168.178.251/media): " REMOTE_PATH
    read -rp "Utente SMB: " SMB_USER
    read -srp "Password SMB: " SMB_PASS
    echo ""
    read -rp "Sola lettura? [s/N]: " READONLY

    if [[ "$READONLY" =~ ^[sS]$ ]]; then
        ACCESS="ro"
        FILE_MODE="0444"
        DIR_MODE="0555"
    else
        ACCESS="rw"
        FILE_MODE="0666"
        DIR_MODE="0777"
    fi

    UNIT_NAME=$(systemd-escape --path "$MOUNT_PATH")
    CRED_FILE="${CRED_DIR}/${UNIT_NAME}.cred"
    UNIT_MOUNT="/etc/systemd/system/${UNIT_NAME}.mount"

    echo ""
    echo "→ Configurazione:"
    echo "  Mount:   $MOUNT_PATH"
    echo "  Remote:  $REMOTE_PATH"
    echo "  Utente:  $SMB_USER"
    echo "  Accesso: $ACCESS (file $FILE_MODE, dir $DIR_MODE)"
    echo "  Unit:    ${UNIT_NAME}.mount"
    echo "  Cred:    $CRED_FILE (0600)"
    echo ""
    echo "  Verrà inoltre abilitato il booleano SELinux 'virt_use_samba',"
    echo "  necessario ai container per accedere a una condivisione CIFS."
    echo ""
    read -rp "Confermi? [s/N]: " CONFIRM
    [[ ! "$CONFIRM" =~ ^[sS]$ ]] && { echo "Operazione annullata."; exit 0; }

    cleanup_on_error() {
        echo ""
        echo "✗ Errore durante la creazione: rimuovo i file parziali."
        sudo rm -f "$UNIT_MOUNT" "$CRED_FILE"
        sudo systemctl daemon-reload || true
    }
    trap cleanup_on_error ERR

    # SELinux: senza questo booleano i container non accedono a CIFS
    if [[ "$(getsebool virt_use_samba | awk '{print $3}')" != "on" ]]; then
        echo "→ Abilito il booleano SELinux virt_use_samba..."
        sudo setsebool -P virt_use_samba on
    fi

    sudo mkdir -p "$MOUNT_PATH"
    sudo mkdir -p "$CRED_DIR"
    sudo chmod 700 "$CRED_DIR"
    printf 'username=%s\npassword=%s\n' "$SMB_USER" "$SMB_PASS" \
        | sudo tee "$CRED_FILE" > /dev/null
    sudo chmod 600 "$CRED_FILE"

    # Mount statico (non automount): i servizi devono poterne dipendere.
    # nofail: se il NAS non risponde, il boot non si blocca.
    printf '%s\n' \
        "[Unit]" \
        "Description=${DESCRIPTION}" \
        "After=network-online.target" \
        "Wants=network-online.target" \
        "" \
        "[Mount]" \
        "What=${REMOTE_PATH}" \
        "Where=${MOUNT_PATH}" \
        "Type=cifs" \
        "Options=${ACCESS},credentials=${CRED_FILE},uid=1000,gid=1000,file_mode=${FILE_MODE},dir_mode=${DIR_MODE},nofail,x-systemd.device-timeout=10" \
        "" \
        "[Install]" \
        "WantedBy=multi-user.target" \
        | sudo tee "$UNIT_MOUNT" > /dev/null

    sudo systemctl daemon-reload
    sudo systemctl enable --now "${UNIT_NAME}.mount"
    trap - ERR

    echo ""
    echo "✓ Mount di sistema '$NAME' creato e attivo."
    echo "  Percorso: $MOUNT_PATH"
    echo "  Unit:     ${UNIT_NAME}.mount"
    echo ""
    echo "  Nei container montalo con:  -v ${MOUNT_PATH}:/media"
    echo "  Nei quadlet aggiungi:       After=${UNIT_NAME}.mount"

# [Rete] Elenca i mount SMB di sistema
smb-system-list:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Mount SMB di sistema (/mnt):"
    echo ""
    FOUND=0
    for unit in /etc/systemd/system/var-mnt-*.mount; do
        [[ -e "$unit" ]] || continue
        FOUND=1
        NAME=$(basename "$unit" .mount)
        WHERE=$(grep '^Where=' "$unit" | cut -d= -f2-)
        WHAT=$(grep '^What=' "$unit" | cut -d= -f2-)
        STATE=$(systemctl is-active "$NAME.mount" 2>/dev/null || echo "inattivo")
        printf '  %-28s %s\n' "$WHERE" "$STATE"
        printf '  %-28s %s\n' "" "$WHAT"
        echo ""
    done
    [[ "$FOUND" -eq 0 ]] && echo "  Nessun mount di sistema configurato."

# [Rete] Rimuove un mount SMB di sistema
smb-system-remove:
    #!/usr/bin/env bash
    set -euo pipefail
    just --justfile {{justfile()}} smb-system-list
    read -rp "Nome del mount da rimuovere (es. media): " NAME
    [[ -z "$NAME" ]] && { echo "Nessun nome fornito."; exit 1; }

    MOUNT_PATH="/mnt/${NAME}"
    UNIT_NAME=$(systemd-escape --path "$MOUNT_PATH")
    UNIT_MOUNT="/etc/systemd/system/${UNIT_NAME}.mount"
    CRED_FILE="/etc/atomik-smb/${UNIT_NAME}.cred"

    if [[ ! -f "$UNIT_MOUNT" ]]; then
        echo "✗ Nessun mount di sistema trovato per '$NAME'."
        exit 1
    fi

    echo ""
    echo "Verranno rimossi:"
    echo "  Mount: $MOUNT_PATH"
    echo "  Unit:  $UNIT_MOUNT"
    echo "  Cred:  $CRED_FILE"
    echo ""
    echo "ATTENZIONE: i servizi che dipendono da questo mount smetteranno di"
    echo "vedere i dati. I file sul server remoto non vengono toccati."
    read -rp "Confermi? [s/N]: " CONFIRM
    [[ ! "$CONFIRM" =~ ^[sS]$ ]] && { echo "Operazione annullata."; exit 0; }

    sudo systemctl disable --now "${UNIT_NAME}.mount" 2>/dev/null || true
    sudo rm -f "$UNIT_MOUNT" "$CRED_FILE"
    sudo systemctl daemon-reload
    sudo rmdir "$MOUNT_PATH" 2>/dev/null || true
    echo "✓ Mount '$NAME' rimosso."
 
# ─────────────────────────────────────────────────────────────────────────────
# Manutenzione
# ─────────────────────────────────────────────────────────────────────────────

# [Manutenzione] Pulisci le immagini bootc non più referenziate
cleanup:
    sudo bootc image prune 2>/dev/null || sudo podman image prune -f
    @echo "✓ Pulizia completata."

