# ═══════════════════════════════════════════════════════════════════════════════
#  Atomik OS — hypervisor.just
#  Funzioni specifiche delal variante Hypervisor. 
#  Importato via `import` dal justfile entrypoint-hypervisor.just.
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# Gestione Macchine virtuali
# ─────────────────────────────────────────────────────────────────────────────

# [VM Manager] List VMs with IP and state (inventory)
vm-list VERBOSE="":
    #!/usr/bin/env bash
    set -uo pipefail
    
    # sudo prima di produrre output
    sudo -v   

    VFLAG=""
    [[ "{{VERBOSE}}" == "verbose" ]] && VFLAG="--verbose"

    printf '%-24s %-17s %-10s %s\n' "NAME" "IP" "STATE" "AUTOSTART"
    printf '%-24s %-17s %-10s %s\n' "------------------------" "-----------------" "----------" "---------"

    while read -r VM; do
        [[ -z "$VM" ]] && continue
        IP=$(/usr/libexec/atomik/vm-resolve-ip "$VM" $VFLAG)
        [[ -z "$IP" ]] && IP="—"
        STATE=$(LC_ALL=C sudo virsh domstate "$VM" 2>/dev/null || echo "unknown")
        if sudo test -e "/etc/libvirt/qemu/autostart/${VM}.xml"; then AUTO="yes"; else AUTO="no"; fi
        printf '%-24s %-17s %-10s %s\n' "$VM" "$IP" "$STATE" "$AUTO"
    done < <(LC_ALL=C sudo virsh list --all --name 2>/dev/null || true)

    echo ""
    echo "(IP resolved via /usr/libexec/atomik/vm-resolve-ip — run 'ujust vm-list verbose' for details)"

# [VM Manager] Aggiorna l'immagine base atomik-server.qcow2 (solo se cambiata)
vm-base-update FORCE="":
    #!/usr/bin/env bash
    set -uo pipefail
    export LC_ALL=C

    BASE_DIR="/var/lib/libvirt/images/base"
    BASE_IMG="${BASE_DIR}/atomik-server.qcow2"
    STAMP="${BASE_IMG}.stamp"
    BASE_URL="https://github.com/giurest/atomik-os/releases/download/server-latest/atomik-server.qcow2"

    sudo mkdir -p "$BASE_DIR"

    # ── Firma remota: ETag (stabile, deterministico sul contenuto) ───────────
    REMOTE_SIG="$(curl -sIL "$BASE_URL" 2>/dev/null \
        | grep -i '^etag:' | tail -1 | tr -d '\r' || true)"

    LOCAL_SIG=""
    [[ -f "$STAMP" ]] && LOCAL_SIG="$(cat "$STAMP" 2>/dev/null || true)"

    # ── Serve scaricare? ─────────────────────────────────────────────────────
    NEED_DOWNLOAD=0
    if [[ ! -f "$BASE_IMG" ]]; then
        echo "→ Immagine base assente."
        NEED_DOWNLOAD=1
    elif [[ "{{FORCE}}" == "force" ]]; then
        echo "→ Download forzato richiesto."
        NEED_DOWNLOAD=1
    elif [[ -z "$REMOTE_SIG" ]]; then
        echo "⚠ Impossibile verificare la versione remota (rete?)."
        echo "  Uso l'immagine locale esistente."
    elif [[ "$REMOTE_SIG" != "$LOCAL_SIG" ]]; then
        echo "→ È disponibile una versione più recente dell'immagine base."
        NEED_DOWNLOAD=1
    else
        echo "✓ Immagine base già aggiornata."
    fi

    # ── Download su file temporaneo, poi sostituzione atomica ────────────────
    if [[ "$NEED_DOWNLOAD" -eq 1 ]]; then
        echo "→ Scarico atomik-server.qcow2 (~1.4 GB)..."
        TMP_IMG="${BASE_IMG}.tmp"
        if sudo curl -fL --progress-bar "$BASE_URL" -o "$TMP_IMG"; then
            sudo mv "$TMP_IMG" "$BASE_IMG"
            sudo restorecon "$BASE_IMG" 2>/dev/null || true
            printf '%s\n' "$REMOTE_SIG" | sudo tee "$STAMP" > /dev/null
            echo "✓ Immagine base aggiornata."
        else
            sudo rm -f "$TMP_IMG"
            echo "✗ Download fallito."
            if [[ -f "$BASE_IMG" ]]; then
                echo "  L'immagine precedente resta utilizzabile."
            else
                exit 1
            fi
        fi
    fi
    
# [VM Manager] Crea una nuova VM Atomik Server
atomik-server:
    #!/usr/bin/env bash
    set -euo pipefail
    export LC_ALL=C

    BASE_DIR="/var/lib/libvirt/images/base"
    BASE_IMG="${BASE_DIR}/atomik-server.qcow2"
    BASE_URL="https://github.com/giurest/atomik-os/releases/download/server-latest/atomik-server.qcow2"
    IMAGES_DIR="/var/lib/libvirt/images"
    BOOT_DIR="/var/lib/libvirt/boot"
    TEMPLATE="/usr/share/atomik/cloud-init/user-data.template"

    echo "═══ Crea VM Atomik Server ═══"
    echo ""

    # ── Parametri interattivi (NIENTE IP: assegnato automaticamente) ─────────
    read -rp "Nome della VM [atomik-vm]: " VM_NAME
    VM_NAME="${VM_NAME:-atomik-vm}"

    read -rp "Username nella VM [giurest]: " VM_USER
    VM_USER="${VM_USER:-giurest}"

    read -rp "RAM in MB [2048]: " VM_RAM
    VM_RAM="${VM_RAM:-2048}"

    read -rp "vCPU [2]: " VM_CPU
    VM_CPU="${VM_CPU:-2}"

    read -rp "Avviare automaticamente al boot dell'hypervisor? [S/n]: " VM_AUTOSTART
    VM_AUTOSTART="${VM_AUTOSTART:-s}"

    # ── Immagine base: aggiorna se necessario (check ETag, leggero) ──────────
    ujust vm-base-update
    if [[ ! -f "$BASE_IMG" ]]; then
        echo "✗ Immagine base non disponibile. Impossibile procedere."
        exit 1
    fi

    # ── Alloca IP+MAC e scrivi la reservation permanente ─────────────────────
    # vm-alloc-ip propone la prima coppia libera (scansiona reservation, lease,
    # ping). NON scrive: la reservation la scriviamo qui, PRIMA di virt-install,
    # cosi' la VM al boot riceve esattamente quell'IP via DHCP.
    read -r VM_MAC VM_IP < <(/usr/libexec/atomik/vm-alloc-ip)
    if [[ -z "$VM_MAC" || -z "$VM_IP" ]]; then
        echo "✗ Allocazione IP/MAC fallita. Impossibile procedere."
        exit 1
    fi

    echo "→ IP assegnato automaticamente: ${VM_IP}  (MAC ${VM_MAC})"
    sudo virsh net-update default add ip-dhcp-host \
        "<host mac='${VM_MAC}' ip='${VM_IP}'/>" --live --config
    echo "✓ Reservation permanente registrata"

    # ── Immagine base: scarica se manca ──────────────────────────────────────
    sudo mkdir -p "$BASE_DIR"
    if [[ ! -f "$BASE_IMG" ]]; then
        echo "→ Immagine base assente, scarico atomik-server.qcow2 (~1.4 GB)..."
        sudo curl -fL --progress-bar "$BASE_URL" -o "$BASE_IMG"
        echo "✓ Immagine base scaricata"
    else
        echo "✓ Immagine base presente: $BASE_IMG"
    fi

    # ── cloud-init: genera user-data e meta-data ─────────────────────────────
    WORKDIR="$(mktemp -d)"
    trap 'rm -rf "$WORKDIR"' EXIT

    sed "s/__USERNAME__/${VM_USER}/g" "$TEMPLATE" > "${WORKDIR}/user-data"
    printf 'instance-id: %s-%s\n' "$VM_NAME" "$(date +%s)" > "${WORKDIR}/meta-data"

    # ── Seed cloud-init (NoCloud: label CIDATA) ──────────────────────────────
    echo "→ Genero il seed cloud-init..."
    (cd "$WORKDIR" && xorriso -as mkisofs -o seed.iso -V CIDATA -J -r user-data meta-data 2>/dev/null)
    sudo cp "${WORKDIR}/seed.iso" "${BOOT_DIR}/${VM_NAME}-seed.iso"
    sudo restorecon "${BOOT_DIR}/${VM_NAME}-seed.iso"

    # ── Disco VM: copia piena dell'immagine base ─────────────────────────────
    echo "→ Copio l'immagine base nel disco della VM..."
    sudo cp "$BASE_IMG" "${IMAGES_DIR}/${VM_NAME}.qcow2"
    sudo restorecon "${IMAGES_DIR}/${VM_NAME}.qcow2"

    # ── Creazione della VM con il MAC riservato ──────────────────────────────
    echo "→ Creo la VM..."
    sudo virt-install --name "$VM_NAME" \
        --memory "$VM_RAM" --vcpus "$VM_CPU" \
        --disk "${IMAGES_DIR}/${VM_NAME}.qcow2,format=qcow2" \
        --disk "${BOOT_DIR}/${VM_NAME}-seed.iso,device=cdrom" \
        --import --os-variant fedora-unknown \
        --network network=default,mac="${VM_MAC}" \
        --graphics none --noautoconsole

    # ── Autostart al boot dell'hypervisor ────────────────────────────────────
    if [[ "$VM_AUTOSTART" =~ ^[sS]$ ]]; then
        sudo virsh autostart "$VM_NAME" > /dev/null
        AUTOSTART_MSG="sì"
    else
        AUTOSTART_MSG="no"
    fi    

    # ── IP gia' noto: nessun polling domifaddr ───────────────────────────────
    echo ""
    echo "✓ VM '$VM_NAME' creata e avviata"
    echo ""
    echo "  IP (permanente):  ${VM_IP}"
    echo "  Autostart:        ${AUTOSTART_MSG}"
    echo "  Accesso:          ssh ${VM_USER}@${VM_IP}"
    echo "  Password:         ${VM_USER}  (da cambiare al primo accesso)"
    echo ""
    echo "  Console:  sudo virsh console $VM_NAME   (Ctrl+] per uscire)"
    echo "  Rimuovi:  ujust vm-delete"

# [VM Manager] Rimuove una VM, il suo storage, la reservation e i port forward
vm-delete:
    #!/usr/bin/env bash
    set -uo pipefail
    export LC_ALL=C
    echo "VM definite:"
    sudo virsh list --all --name
    echo ""
    read -rp "Nome della VM da rimuovere: " VM_NAME
    [[ -z "$VM_NAME" ]] && { echo "Nessun nome fornito."; exit 1; }

    if [[ "$VM_NAME" =~ ^[0-9]+$ ]]; then
        echo "✗ Inserisci il NOME della VM, non l'Id numerico."
        echo "  Gli Id cambiano e spariscono dopo lo spegnimento; il nome è stabile."
        exit 1
    fi
    if ! sudo virsh dominfo "$VM_NAME" &>/dev/null; then
        echo "✗ La VM '$VM_NAME' non esiste."
        exit 1
    fi

    VM_MAC="$(sudo virsh domiflist "$VM_NAME" 2>/dev/null \
        | awk '$3 == "default" {print $5}' | head -1 || true)"

    VM_IP=""
    if [[ -n "$VM_MAC" ]]; then
        VM_IP="$(sudo virsh net-dumpxml default 2>/dev/null \
            | grep -oE "<host mac='${VM_MAC}' ip='[0-9.]+'" \
            | grep -oE "ip='[0-9.]+'" | sed "s/ip='//; s/'//" | head -1 || true)"
    fi

    # ── Forward associati: rilevali PRIMA della conferma per mostrarli ────────
    FORWARDS="$(ls /etc/systemd/system/ 2>/dev/null \
        | grep -E "^vm-forward-${VM_NAME}-[0-9]+\.service$" || true)"

    echo ""
    echo "ATTENZIONE: procedura irreversibile. I dati nella VM non saranno recuperabili."
    [[ -n "$VM_IP" ]] && echo "  Reservation associata: ${VM_MAC} → ${VM_IP} (verrà rimossa)"
    if [[ -n "$FORWARDS" ]]; then
        echo "  Port forward che verranno rimossi:"
        while IFS= read -r svc; do
            [[ -n "$svc" ]] && echo "    - ${svc}"
        done <<< "$FORWARDS"
    fi
    read -rp "Rimuovere '$VM_NAME' e TUTTI i suoi dischi? [s/N]: " CONFIRM
    [[ "${CONFIRM,,}" != "s" ]] && { echo "Operazione annullata."; exit 0; }

    # ── 1. Distruggi e rimuovi la VM + storage ───────────────────────────────
    sudo virsh destroy "$VM_NAME" 2>/dev/null || true
    if ! sudo virsh undefine "$VM_NAME" --remove-all-storage; then
        echo "✗ undefine fallito. La VM potrebbe essere ancora definita."
        echo "  Stato sporco: verifica con 'sudo virsh list --all'."
    else
        echo "✓ VM '$VM_NAME' e dischi rimossi"
    fi

    # ── 2. Rimuovi il seed cloud-init ────────────────────────────────────────
    sudo rm -f "/var/lib/libvirt/boot/${VM_NAME}-seed.iso"

    # ── 3. Rimuovi la reservation (libera l'IP per la prossima VM) ────────────
    if [[ -n "$VM_MAC" && -n "$VM_IP" ]]; then
        if sudo virsh net-update default delete ip-dhcp-host \
            "<host mac='${VM_MAC}' ip='${VM_IP}'/>" --live --config 2>/dev/null; then
            echo "✓ Reservation ${VM_IP} liberata"
        else
            echo "⚠ Reservation ${VM_MAC} → ${VM_IP} non rimossa (forse già assente)."
            echo "  Verifica con: sudo virsh net-dumpxml default"
        fi
    else
        echo "⚠ Nessuna reservation trovata per '$VM_NAME' (VM creata fuori dalle recipe?)."
    fi

    # ── 4. Rimuovi i port forward associati ──────────────────────────────────
    # I forward sono servizi socat sull'hypervisor, indipendenti dalla VM:
    # senza questa pulizia restano orfani (socat attivi, porte firewall aperte).
    if [[ -n "$FORWARDS" ]]; then
        echo "→ Rimuovo i port forward associati..."
        while IFS= read -r svc; do
            [[ -z "$svc" ]] && continue
            HOST_PORT="$(echo "$svc" | grep -oE '[0-9]+\.service$' | grep -oE '^[0-9]+')"
            sudo systemctl disable --now "$svc" 2>/dev/null || true
            sudo rm -f "/etc/systemd/system/${svc}"
            [[ -n "$HOST_PORT" ]] && sudo firewall-cmd --permanent --remove-port="${HOST_PORT}/tcp" >/dev/null 2>&1 || true
            echo "  ✓ rimosso ${svc}"
        done <<< "$FORWARDS"
        sudo systemctl daemon-reload
        sudo firewall-cmd --reload >/dev/null 2>&1 || true
    fi

    echo "✓ Rimozione completata"
    
# ─────────────────────────────────────────────────────────────────────────────
# Gestione Forward macchine virtuali
# ─────────────────────────────────────────────────────────────────────────────

# [VM Manager] Expose a VM service port on the LAN (persistent socat forward)
vm-forward NAME PORTA_VM PORTA_HOST="" VERBOSE="":
    #!/usr/bin/env bash
    set -uo pipefail
    sudo -v

    NAME="{{NAME}}"
    PORTA_VM="{{PORTA_VM}}"
    PORTA_HOST="{{PORTA_HOST}}"
    [[ -z "$PORTA_HOST" ]] && PORTA_HOST="$PORTA_VM"

    VFLAG=""
    [[ "{{VERBOSE}}" == "verbose" ]] && VFLAG="--verbose"

    # Resolve VM IP via the shared helper (single source of truth)
    IP=$(/usr/libexec/atomik/vm-resolve-ip "$NAME" $VFLAG)
    if [[ -z "$IP" ]]; then
        echo "✗ Could not resolve an IP for VM '$NAME'."
        echo "  Check the name with 'ujust vm-list'."
        exit 1
    fi

    # Reject privileged ports (protect ssh and system services)
    if (( PORTA_HOST < 1024 )); then
        echo "✗ Host port $PORTA_HOST is privileged (<1024)."
        echo "  Choose a host port >= 1024."
        exit 1
    fi

    SERVICE="vm-forward-${NAME}-${PORTA_HOST}.service"
    UNIT_PATH="/etc/systemd/system/${SERVICE}"

    # Is the host port already in use? If so, suggest the next free one and exit.
    if sudo ss -tlnH "( sport = :${PORTA_HOST} )" 2>/dev/null | grep -q .; then
        # find the next free port (bounded search)
        SUGGESTED=""
        for (( p=PORTA_HOST+1; p<=PORTA_HOST+20; p++ )); do
            if ! sudo ss -tlnH "( sport = :${p} )" 2>/dev/null | grep -q .; then
                SUGGESTED="$p"; break
            fi
        done

        echo "⚠ Host port ${PORTA_HOST} is already in use."
        # try to name the conflicting forward, if it is one of ours
        CONFLICT=$(ls /etc/systemd/system/ 2>/dev/null \
            | grep -E "^vm-forward-.*-${PORTA_HOST}\.service$" | head -1 || true)
        [[ -n "$CONFLICT" ]] && echo "  In use by forward: ${CONFLICT}"

        if [[ -n "$SUGGESTED" ]]; then
            echo "  Suggested free port: ${SUGGESTED}"
            echo ""
            echo "  To create the forward on that port, run:"
            echo ""
            echo "      ujust vm-forward ${NAME} ${PORTA_VM} ${SUGGESTED}"
            echo ""
        else
            echo "  No free port found near ${PORTA_HOST}. Pick another host port."
        fi
        echo "Operation cancelled."
        exit 1
    fi

    # Warn (non-blocking) if the VM service isn't answering yet
    if ! timeout 3 bash -c "echo > /dev/tcp/${IP}/${PORTA_VM}" 2>/dev/null; then
        echo "⚠ ${IP}:${PORTA_VM} is not answering right now."
        echo "  The forward will still be created (socat retries; the VM service may start later)."
    fi

    echo ""
    echo "→ Forward:"
    echo "  LAN :${PORTA_HOST}  ->  ${NAME} (${IP}:${PORTA_VM})"
    echo "  Service: ${SERVICE}"
    echo ""

    # Write the hardened systemd service (validated by hand)
    printf '%s\n' \
        "[Unit]" \
        "Description=Port forward LAN:${PORTA_HOST} -> ${NAME} (${IP}:${PORTA_VM})" \
        "After=network-online.target" \
        "Wants=network-online.target" \
        "" \
        "[Service]" \
        "ExecStart=/usr/bin/socat TCP-LISTEN:${PORTA_HOST},fork,reuseaddr TCP:${IP}:${PORTA_VM},retry=3,interval=2" \
        "DynamicUser=yes" \
        "NoNewPrivileges=yes" \
        "ProtectSystem=strict" \
        "ProtectHome=yes" \
        "PrivateTmp=yes" \
        "RestrictAddressFamilies=AF_INET AF_INET6" \
        "Restart=on-failure" \
        "RestartSec=5" \
        "" \
        "[Install]" \
        "WantedBy=multi-user.target" \
        | sudo tee "$UNIT_PATH" > /dev/null

    sudo systemctl daemon-reload
    sudo systemctl enable --now "$SERVICE"

    # Open the host port permanently on the LAN zone
    sudo firewall-cmd --permanent --add-port=${PORTA_HOST}/tcp > /dev/null
    sudo firewall-cmd --reload > /dev/null

    echo "✓ Forward active and persistent."
    echo "  Reach it at: http://<hypervisor-ip>:${PORTA_HOST}"
    echo "  Remove with: ujust vm-forward-remove ${NAME} ${PORTA_HOST}"

# [VM Manager] List active VM port forwards
vm-forward-list:
    #!/usr/bin/env bash
    set -uo pipefail
    sudo -v
    printf '%-40s %-12s %s\n' "SERVICE" "STATE" "FORWARD"
    printf '%-40s %-12s %s\n' "----------------------------------------" "------------" "-------"
    FOUND=0
    for unit in /etc/systemd/system/vm-forward-*.service; do
        [[ -e "$unit" ]] || continue
        FOUND=1
        SVC=$(basename "$unit")
        STATE=$(systemctl is-active "$SVC" 2>/dev/null || echo "inactive")
        DESC=$(grep -oP '^Description=\K.*' "$unit" 2>/dev/null || true)
        printf '%-40s %-12s %s\n' "$SVC" "$STATE" "$DESC"
    done
    if [[ "$FOUND" -eq 0 ]]; then
        echo "  No forwards configured."
    fi

# [VM Manager] Remove a VM port forward (service + firewall port)
vm-forward-remove NAME PORTA_HOST:
    #!/usr/bin/env bash
    set -uo pipefail
    sudo -v

    SERVICE="vm-forward-{{NAME}}-{{PORTA_HOST}}.service"
    UNIT_PATH="/etc/systemd/system/${SERVICE}"

    if [[ ! -f "$UNIT_PATH" ]]; then
        echo "✗ No forward found: ${SERVICE}"
        echo "  See active forwards with 'ujust vm-forward-list'."
        exit 1
    fi

    echo "Removing forward ${SERVICE} and closing host port {{PORTA_HOST}}/tcp."
    read -rp "Confirm? [y/N]: " CONFIRM
    [[ ! "$CONFIRM" =~ ^[yYsS]$ ]] && { echo "Cancelled."; exit 0; }

    sudo systemctl disable --now "$SERVICE" 2>/dev/null || true
    sudo rm -f "$UNIT_PATH"
    sudo systemctl daemon-reload
    sudo firewall-cmd --permanent --remove-port={{PORTA_HOST}}/tcp > /dev/null 2>&1 || true
    sudo firewall-cmd --reload > /dev/null

    echo "✓ Forward removed."

# [VM Manager] Backup completo delle VM sul NAS (disco + definizione + reservation)
vm-backup NOME="" VERSIONI="2":
    #!/usr/bin/env bash
    set -uo pipefail
    export LC_ALL=C

    BACKUP_ROOT="/var/mnt/backup"
    IMAGES_DIR="/var/lib/libvirt/images"
    BOOT_DIR="/var/lib/libvirt/boot"
    LOG_DIR="${BACKUP_ROOT}/log"
    ERR_DIR="${BACKUP_ROOT}/log_errori"
    KEEP="{{VERSIONI}}"
    RUN_TS="$(date +%Y-%m-%d_%H%M%S)"
    LOG_FILE="${LOG_DIR}/${RUN_TS}.log"
    ERR_FILE="${ERR_DIR}/${RUN_TS}.log"

    # ── Verifica che il mount di backup sia attivo ───────────────────────────
    if ! mountpoint -q "$BACKUP_ROOT" 2>/dev/null; then
        echo "✗ Il NAS di backup non è montato in ${BACKUP_ROOT}."
        echo "  Montalo con: ujust smb-system backup"
        exit 1
    fi

    sudo mkdir -p "$LOG_DIR" "$ERR_DIR"

    # Logging: log() sempre; err() anche su file errori (creato solo se serve)
    log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | sudo tee -a "$LOG_FILE" >/dev/null; }
    err() {
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" | sudo tee -a "$LOG_FILE" "$ERR_FILE" >/dev/null
    }

    # ── Determina la lista delle VM da salvare ───────────────────────────────
    if [[ -n "{{NOME}}" ]]; then
        if ! sudo virsh dominfo "{{NOME}}" &>/dev/null; then
            echo "✗ La VM '{{NOME}}' non esiste."
            exit 1
        fi
        VMS="{{NOME}}"
    else
        VMS="$(sudo virsh list --all --name | grep -v '^$' || true)"
    fi

    if [[ -z "$VMS" ]]; then
        echo "✗ Nessuna VM da salvare."
        exit 1
    fi

    TOTAL=0; OK=0; SKIP=0; FAIL=0
    log "[START] backup — versioni da mantenere: ${KEEP}"
    echo "═══ Backup VM → ${BACKUP_ROOT} ═══"
    echo ""

    # ── Ciclo sulle VM ───────────────────────────────────────────────────────
    while IFS= read -r VM; do
        [[ -z "$VM" ]] && continue
        TOTAL=$((TOTAL+1))
        echo "→ ${VM}"

        QCOW="${IMAGES_DIR}/${VM}.qcow2"
        SEED="${BOOT_DIR}/${VM}-seed.iso"
        DEST="${BACKUP_ROOT}/${VM}/${RUN_TS}"

        if [[ ! -f "$QCOW" ]]; then
            err "[${VM}] ERRORE: disco non trovato (${QCOW}) — VM SALTATA"
            echo "  ✗ disco non trovato, salto"
            SKIP=$((SKIP+1))
            continue
        fi

        # ── Stato iniziale, per riavviare solo se era accesa ─────────────────
        WAS_RUNNING=0
        if sudo virsh domstate "$VM" 2>/dev/null | grep -q running; then
            WAS_RUNNING=1
        fi

        # ── Shutdown graceful (timeout 120s, NO forzatura) ───────────────────
        if [[ "$WAS_RUNNING" -eq 1 ]]; then
            log "[${VM}] shutdown avviato"
            echo "  shutdown..."
            sudo virsh shutdown "$VM" >/dev/null 2>&1 || true
            WAITED=0
            while (( WAITED < 120 )); do
                sudo virsh domstate "$VM" 2>/dev/null | grep -q "shut off" && break
                sleep 3; WAITED=$((WAITED+3))
            done
            if ! sudo virsh domstate "$VM" 2>/dev/null | grep -q "shut off"; then
                err "[${VM}] ERRORE: shutdown non completato entro 120s — VM SALTATA (resta accesa)"
                echo "  ✗ shutdown fallito, salto (VM resta accesa)"
                SKIP=$((SKIP+1))
                continue
            fi
            log "[${VM}] shutdown completato (${WAITED}s)"
        else
            log "[${VM}] già spenta, copio direttamente"
        fi

        # ── Copia dei file ───────────────────────────────────────────────────
        sudo mkdir -p "$DEST"
        COPY_OK=1
        echo "  copia disco..."
        log "[${VM}] copia qcow2"
        sudo cp "$QCOW" "${DEST}/${VM}.qcow2" || COPY_OK=0
        sudo virsh dumpxml "$VM" | sudo tee "${DEST}/${VM}.xml" >/dev/null || COPY_OK=0
        [[ -f "$SEED" ]] && { sudo cp "$SEED" "${DEST}/${VM}-seed.iso" || COPY_OK=0; }

        # reservation: estrai la riga <host> dal MAC della VM
        VM_MAC="$(sudo virsh domiflist "$VM" 2>/dev/null | awk '$3=="default"{print $5}' | head -1 || true)"
        if [[ -n "$VM_MAC" ]]; then
            sudo virsh net-dumpxml default 2>/dev/null \
                | grep -oE "<host mac='${VM_MAC}'[^>]*/>" \
                | sudo tee "${DEST}/${VM}.reservation" >/dev/null || true
        fi

    # ── Forward associati alla VM ────────────────────────────────────────────
    FWD_FILES="$(ls /etc/systemd/system/vm-forward-${VM}-*.service 2>/dev/null || true)"
    if [[ -n "$FWD_FILES" ]]; then
        sudo mkdir -p "${DEST}/forwards"
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            sudo cp "$f" "${DEST}/forwards/"
        done <<< "$FWD_FILES"
        log "[${VM}] salvati $(echo "$FWD_FILES" | wc -l) forward"
    fi

        # ── Riavvia SUBITO dopo la copia (minimizza il downtime) ─────────────
        if [[ "$WAS_RUNNING" -eq 1 ]]; then
            sudo virsh start "$VM" >/dev/null 2>&1 || err "[${VM}] AVVISO: riavvio fallito"
            log "[${VM}] riavvio VM"
            echo "  riavviata"
        fi

        if [[ "$COPY_OK" -ne 1 ]]; then
            err "[${VM}] ERRORE: copia incompleta — backup NON valido"
            echo "  ✗ copia incompleta"
            FAIL=$((FAIL+1))
            continue
        fi

        # ── Verifica L1 (checksum) + L2 (qemu-img check) → MANIFEST ──────────
        echo "  verifica..."
        MANIFEST="${DEST}/MANIFEST"
        STATUS="verified"

        # L2: integrità del qcow2
        if sudo qemu-img check "${DEST}/${VM}.qcow2" >/dev/null 2>&1; then
            QCHECK="passed"
        else
            QCHECK="FAILED"
            STATUS="FAILED"
            err "[${VM}] ERRORE: qemu-img check fallito sul backup"
        fi

        # L1: checksum di tutti i file (nel MANIFEST)
        {
            echo "vm: ${VM}"
            echo "timestamp: ${RUN_TS}"
            echo "created: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
            echo "hypervisor: $(hostname)"
            echo "qcow2_check: ${QCHECK}"
            echo "files:"
            for f in "${DEST}/${VM}.qcow2" "${DEST}/${VM}.xml" \
                     "${DEST}/${VM}-seed.iso" "${DEST}/${VM}.reservation" \
             "${DEST}"/forwards/*.service; do
                [[ -f "$f" ]] || continue
                H="$(sudo sha256sum "$f" | awk '{print $1}')"
                S="$(sudo stat -c%s "$f")"
                echo "  $(basename "$f")  sha256:${H}  size:${S}"
            done
            echo "status: ${STATUS}"
        } | sudo tee "$MANIFEST" >/dev/null

        if [[ "$STATUS" == "verified" ]]; then
            log "[${VM}] MANIFEST scritto, status: verified"
            echo "  ✓ verificato"
            OK=$((OK+1))
        else
            log "[${VM}] MANIFEST scritto, status: FAILED"
            echo "  ✗ verifica fallita (vedi log_errori)"
            FAIL=$((FAIL+1))
        fi

        # ── Rotazione: mantieni solo le ultime ${KEEP} versioni ──────────────
        MAPFILE=$(ls -1dr "${BACKUP_ROOT}/${VM}"/*/ 2>/dev/null || true)
        if [[ -n "$MAPFILE" ]]; then
            COUNT=0
            while IFS= read -r d; do
                [[ -z "$d" ]] && continue
                COUNT=$((COUNT+1))
                if (( COUNT > KEEP )); then
                    sudo rm -rf "$d"
                    log "[${VM}] rotazione: rimossa versione $(basename "$d")"
                fi
            done <<< "$MAPFILE"
        fi

        echo ""
    done <<< "$VMS"

    # ── Riepilogo ────────────────────────────────────────────────────────────
    log "[END] completato: ${OK} OK, ${SKIP} saltate, ${FAIL} errori (su ${TOTAL})"
    echo "═══ Riepilogo ═══"
    echo "  Totale:  ${TOTAL}"
    echo "  OK:      ${OK}"
    echo "  Saltate: ${SKIP}"
    echo "  Errori:  ${FAIL}"
    echo ""
    echo "  Log:     ${LOG_FILE}"
    if [[ "$SKIP" -gt 0 || "$FAIL" -gt 0 ]]; then
        echo "  ⚠ Errori/salti registrati in: ${ERR_FILE}"
    else
        echo "  ✓ Nessun errore."
    fi

# [VM Manager] Ripristina una VM da backup (disco + definizione + reservation + forward)
vm-restore NOME="" TIMESTAMP="":
    #!/usr/bin/env bash
    set -uo pipefail
    export LC_ALL=C

    BACKUP_ROOT="/var/mnt/backup"
    IMAGES_DIR="/var/lib/libvirt/images"
    BOOT_DIR="/var/lib/libvirt/boot"

    VM="{{NOME}}"
    TS="{{TIMESTAMP}}"

    if [[ -z "$VM" ]]; then
        echo "✗ Specifica la VM da ripristinare: ujust vm-restore <nome> [timestamp]"
        echo ""
        echo "  Backup disponibili:"
        ls -1 "$BACKUP_ROOT" 2>/dev/null | grep -vE '^(log|log_errori)$' | sed 's/^/    /'
        exit 1
    fi

    # ── Mount attivo? ────────────────────────────────────────────────────────
    if ! mountpoint -q "$BACKUP_ROOT" 2>/dev/null; then
        echo "✗ Il NAS di backup non è montato in ${BACKUP_ROOT}."
        echo "  Montalo con: ujust smb-system backup"
        exit 1
    fi

    VM_BACKUP_DIR="${BACKUP_ROOT}/${VM}"
    if [[ ! -d "$VM_BACKUP_DIR" ]]; then
        echo "✗ Nessun backup trovato per '${VM}'."
        exit 1
    fi

    # ── Determina il timestamp: specificato o il più recente ─────────────────
    if [[ -z "$TS" ]]; then
        TS="$(ls -1r "$VM_BACKUP_DIR" 2>/dev/null | head -1 || true)"
        [[ -z "$TS" ]] && { echo "✗ Nessuna versione di backup per '${VM}'."; exit 1; }
        echo "→ Uso il backup più recente: ${TS}"
    fi

    SRC="${VM_BACKUP_DIR}/${TS}"
    MANIFEST="${SRC}/MANIFEST"
    if [[ ! -f "$MANIFEST" ]]; then
        echo "✗ Backup non valido: MANIFEST assente in ${SRC}"
        exit 1
    fi

    # ── Verifica status del MANIFEST ─────────────────────────────────────────
    STATUS="$(grep '^status:' "$MANIFEST" | awk '{print $2}')"
    if [[ "$STATUS" != "verified" ]]; then
        echo "✗ Il backup ha status '${STATUS}', non 'verified'. Ripristino rifiutato."
        exit 1
    fi

    # ── Verifica checksum (il backup potrebbe essersi corrotto sul NAS) ──────
    echo "→ Verifico l'integrità del backup..."
    CHECK_FAIL=0
    while IFS= read -r line; do
        FNAME="$(echo "$line" | awk '{print $1}')"
        EXPECTED="$(echo "$line" | grep -oE 'sha256:[a-f0-9]+' | cut -d: -f2)"
        [[ -z "$FNAME" || -z "$EXPECTED" ]] && continue
        # il file può stare nella root del backup o in forwards/
        FPATH="${SRC}/${FNAME}"
        [[ -f "$FPATH" ]] || FPATH="${SRC}/forwards/${FNAME}"
        if [[ ! -f "$FPATH" ]]; then
            echo "  ✗ file mancante: ${FNAME}"
            CHECK_FAIL=1
            continue
        fi
        ACTUAL="$(sudo sha256sum "$FPATH" | awk '{print $1}')"
        if [[ "$ACTUAL" != "$EXPECTED" ]]; then
            echo "  ✗ checksum non corrisponde: ${FNAME}"
            CHECK_FAIL=1
        fi
    done < <(sed -n '/^files:/,/^status:/p' "$MANIFEST" | grep -E 'sha256:')

    if [[ "$CHECK_FAIL" -ne 0 ]]; then
        echo "✗ Verifica integrità FALLITA. Il backup è corrotto, ripristino annullato."
        exit 1
    fi
    echo "  ✓ integrità confermata"

    # ── La VM non deve già esistere ──────────────────────────────────────────
    if sudo virsh dominfo "$VM" &>/dev/null; then
        echo "✗ La VM '${VM}' esiste già."
        echo "  Eliminala prima con 'ujust vm-delete', poi riprova il ripristino."
        exit 1
    fi

    # ── Estrai MAC e IP dalla reservation salvata ────────────────────────────
    RES_LINE="$(cat "${SRC}/${VM}.reservation" 2>/dev/null || true)"
    RES_MAC="$(echo "$RES_LINE" | grep -oE "mac='[^']+'" | sed "s/mac='//; s/'//")"
    RES_IP="$(echo "$RES_LINE" | grep -oE "ip='[^']+'" | sed "s/ip='//; s/'//")"

    # ── IP e MAC devono essere liberi (non presi da altre VM nel frattempo) ──
    if [[ -n "$RES_IP" ]]; then
        CUR_XML="$(sudo virsh net-dumpxml default 2>/dev/null || true)"
        if echo "$CUR_XML" | grep -q "ip='${RES_IP}'" && ! echo "$CUR_XML" | grep -q "$RES_LINE"; then
            echo "✗ L'IP ${RES_IP} è già assegnato a un'altra VM."
            echo "  Il ripristino creerebbe un conflitto. Libera l'IP prima di procedere."
            exit 1
        fi
    fi

    # ── Riepilogo e conferma ─────────────────────────────────────────────────
    echo ""
    echo "→ Ripristino:"
    echo "  VM:         ${VM}"
    echo "  Backup:     ${TS}"
    [[ -n "$RES_IP" ]] && echo "  IP:         ${RES_IP} (MAC ${RES_MAC})"
    if [[ -d "${SRC}/forwards" ]]; then
        echo "  Forward:    $(ls -1 "${SRC}/forwards" 2>/dev/null | wc -l) da ripristinare"
    fi
    echo ""
    read -rp "Procedere con il ripristino? [s/N]: " CONFIRM
    [[ "${CONFIRM,,}" != "s" ]] && { echo "Operazione annullata."; exit 0; }

    # ── 1. Ripristina disco e seed nelle posizioni originali ─────────────────
    echo "→ Ripristino disco..."
    sudo cp "${SRC}/${VM}.qcow2" "${IMAGES_DIR}/${VM}.qcow2"
    sudo restorecon "${IMAGES_DIR}/${VM}.qcow2" 2>/dev/null || true
    if [[ -f "${SRC}/${VM}-seed.iso" ]]; then
        sudo cp "${SRC}/${VM}-seed.iso" "${BOOT_DIR}/${VM}-seed.iso"
        sudo restorecon "${BOOT_DIR}/${VM}-seed.iso" 2>/dev/null || true
    fi

    # ── 2. Reservation nella network XML ─────────────────────────────────────
    if [[ -n "$RES_MAC" && -n "$RES_IP" ]]; then
        if ! echo "$CUR_XML" | grep -q "$RES_LINE"; then
            sudo virsh net-update default add ip-dhcp-host \
                "$RES_LINE" --live --config >/dev/null 2>&1 \
                && echo "✓ Reservation ${RES_IP} ripristinata" \
                || echo "⚠ Reservation non aggiunta (forse già presente)"
        else
            echo "✓ Reservation ${RES_IP} già presente"
        fi
    fi

    # ── 3. Definisci la VM dalla XML salvata (fedele all'originale) ──────────
    echo "→ Definisco la VM..."
    sudo virsh define "${SRC}/${VM}.xml" >/dev/null

    # ── 4. Ripristina i forward ──────────────────────────────────────────────
    if [[ -d "${SRC}/forwards" ]]; then
        echo "→ Ripristino i port forward..."
        for f in "${SRC}"/forwards/*.service; do
            [[ -f "$f" ]] || continue
            SVC="$(basename "$f")"
            HOST_PORT="$(echo "$SVC" | grep -oE '[0-9]+\.service$' | grep -oE '^[0-9]+')"
            sudo cp "$f" "/etc/systemd/system/${SVC}"
            [[ -n "$HOST_PORT" ]] && sudo firewall-cmd --permanent --add-port="${HOST_PORT}/tcp" >/dev/null 2>&1 || true
        done
        sudo systemctl daemon-reload
        sudo firewall-cmd --reload >/dev/null 2>&1 || true
        for f in "${SRC}"/forwards/*.service; do
            [[ -f "$f" ]] || continue
            sudo systemctl enable --now "$(basename "$f")" >/dev/null 2>&1 || true
        done
        echo "✓ Forward ripristinati"
    fi

    # ── 5. Avvia la VM ───────────────────────────────────────────────────────
    echo "→ Avvio la VM..."
    sudo virsh start "$VM" >/dev/null 2>&1 || true
    sudo virsh autostart "$VM" >/dev/null 2>&1 || true

    echo ""
    echo "✓ VM '${VM}' ripristinata dal backup ${TS}"
    [[ -n "$RES_IP" ]] && echo "  IP: ${RES_IP}"
    echo "  Verifica con: ujust vm-list"

# [VM Manager] Elenca i backup disponibili sul NAS (VM, data, stato, dimensione)
vm-backup-list NOME="":
    #!/usr/bin/env bash
    set -uo pipefail
    export LC_ALL=C

    BACKUP_ROOT="/var/mnt/backup"

    # ── Mount attivo? ────────────────────────────────────────────────────────
    if ! mountpoint -q "$BACKUP_ROOT" 2>/dev/null; then
        echo "✗ Il NAS di backup non è montato in ${BACKUP_ROOT}."
        echo "  Montalo con: ujust smb-system backup"
        exit 1
    fi

    # ── Determina le VM da elencare ──────────────────────────────────────────
    if [[ -n "{{NOME}}" ]]; then
        VM_DIRS="${BACKUP_ROOT}/{{NOME}}"
        [[ ! -d "$VM_DIRS" ]] && { echo "✗ Nessun backup per '{{NOME}}'."; exit 1; }
    else
        VM_DIRS="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d \
            ! -name log ! -name log_errori 2>/dev/null | sort || true)"
    fi

    if [[ -z "$VM_DIRS" ]]; then
        echo "Nessun backup presente in ${BACKUP_ROOT}."
        exit 0
    fi

    printf '%-22s %-20s %-10s %s\n' "VM" "TIMESTAMP" "STATO" "DIMENSIONE"
    printf '%-22s %-20s %-10s %s\n' "----------------------" "--------------------" "----------" "----------"

    FOUND=0
    while IFS= read -r vmdir; do
        [[ -z "$vmdir" ]] && continue
        VM="$(basename "$vmdir")"

        # ogni sottocartella timestamp, dalla più recente
        BACKUPS="$(find "$vmdir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -r || true)"
        [[ -z "$BACKUPS" ]] && continue

        while IFS= read -r bdir; do
            [[ -z "$bdir" ]] && continue
            FOUND=1
            TS="$(basename "$bdir")"
            MANIFEST="${bdir}/MANIFEST"

            if [[ -f "$MANIFEST" ]]; then
                STATUS="$(grep '^status:' "$MANIFEST" 2>/dev/null | awk '{print $2}')"
                [[ -z "$STATUS" ]] && STATUS="?"
            else
                STATUS="no-manifest"
            fi

            # dimensione totale del backup (leggibile)
            SIZE="$(du -sh "$bdir" 2>/dev/null | awk '{print $1}' || echo '?')"

            # marca visiva per stato non verificato
            MARK=""
            [[ "$STATUS" != "verified" ]] && MARK=" ⚠"

            printf '%-22s %-20s %-10s %s%s\n' "$VM" "$TS" "$STATUS" "$SIZE" "$MARK"
        done <<< "$BACKUPS"
    done <<< "$VM_DIRS"

    if [[ "$FOUND" -eq 0 ]]; then
        echo "Nessun backup presente."
    fi

# [VM Manager] Verifica L3: boot di prova di un backup in una VM temporanea isolata
vm-backup-verify NOME="" TIMESTAMP="":
    #!/usr/bin/env bash
    set -uo pipefail
    export LC_ALL=C

    BACKUP_ROOT="/var/mnt/backup"
    IMAGES_DIR="/var/lib/libvirt/images"

    VM="{{NOME}}"
    TS="{{TIMESTAMP}}"

    [[ -z "$VM" ]] && { echo "✗ Uso: ujust vm-backup-verify <nome> [timestamp]"; exit 1; }

    if ! mountpoint -q "$BACKUP_ROOT" 2>/dev/null; then
        echo "✗ Il NAS di backup non è montato in ${BACKUP_ROOT}."
        exit 1
    fi

    VM_BACKUP_DIR="${BACKUP_ROOT}/${VM}"
    [[ ! -d "$VM_BACKUP_DIR" ]] && { echo "✗ Nessun backup per '${VM}'."; exit 1; }

    if [[ -z "$TS" ]]; then
        TS="$(ls -1r "$VM_BACKUP_DIR" 2>/dev/null | head -1 || true)"
        [[ -z "$TS" ]] && { echo "✗ Nessuna versione di backup."; exit 1; }
        echo "→ Verifico il backup più recente: ${TS}"
    fi

    SRC="${VM_BACKUP_DIR}/${TS}"
    MANIFEST="${SRC}/MANIFEST"
    QCOW_SRC="${SRC}/${VM}.qcow2"
    [[ ! -f "$MANIFEST" ]] && { echo "✗ MANIFEST assente in ${SRC}"; exit 1; }
    [[ ! -f "$QCOW_SRC" ]] && { echo "✗ Disco di backup assente."; exit 1; }

    # ── Nome, disco e MAC temporanei (isolati: NON collidono con l'originale) ─
    VTMP="verify-${VM}"
    # tronca il nome se troppo lungo per libvirt
    VTMP="${VTMP:0:40}"
    TMP_QCOW="${IMAGES_DIR}/${VTMP}.qcow2"
    # MAC casuale nuovo: la VM di prova prende un IP dal POOL, non la reservation
    TMP_MAC="$(printf '52:54:00:%02x:%02x:%02x' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))"

    echo ""
    echo "→ Verifica di boot (L3) — VM temporanea isolata"
    echo "  Backup:   ${VM} @ ${TS}"
    echo "  VM prova: ${VTMP} (MAC ${TMP_MAC}, IP dal pool)"
    echo ""

    # Funzione di pulizia: rimuove SEMPRE la VM temporanea, anche su errore
    cleanup() {
        sudo virsh destroy "$VTMP" >/dev/null 2>&1 || true
        sudo virsh undefine "$VTMP" >/dev/null 2>&1 || true
        sudo rm -f "$TMP_QCOW"
    }
    trap cleanup EXIT

    # ── Se per caso esiste già una VM verify- precedente, ripulisci ──────────
    if sudo virsh dominfo "$VTMP" &>/dev/null; then
        echo "→ Rimuovo una VM di verifica precedente..."
        sudo virsh destroy "$VTMP" >/dev/null 2>&1 || true
        sudo virsh undefine "$VTMP" >/dev/null 2>&1 || true
    fi

    # ── Copia il disco del backup in una posizione temporanea ────────────────
    echo "→ Copio il disco del backup..."
    sudo cp "$QCOW_SRC" "$TMP_QCOW"
    sudo restorecon "$TMP_QCOW" 2>/dev/null || true

    # ── Crea e avvia la VM temporanea (MAC nuovo, IP dal pool) ───────────────
    # Niente seed cloud-init, niente reservation: ci interessa solo che BOOTI
    # e prenda un IP. RAM/CPU minime per non pesare sull'hypervisor.
    echo "→ Avvio la VM di prova..."
    if ! sudo virt-install --name "$VTMP" \
        --memory 1024 --vcpus 1 \
        --disk "${TMP_QCOW},format=qcow2" \
        --import --os-variant fedora-unknown \
        --network network=default,mac="${TMP_MAC}" \
        --graphics none --noautoconsole >/dev/null 2>&1; then
        echo "✗ VERIFICA FALLITA: la VM di prova non si è avviata (virt-install)."
        exit 1
    fi

    # ── Attendi che prenda un IP (fino a 120s) ───────────────────────────────
    echo "→ Attendo che la VM prenda un IP dal DHCP..."
    GOT_IP=""
    WAITED=0
    while (( WAITED < 120 )); do
        sleep 5; WAITED=$((WAITED+5))
        GOT_IP="$(sudo virsh domifaddr "$VTMP" 2>/dev/null \
            | awk '/ipv4/ {print $4}' | cut -d/ -f1 | head -1 || true)"
        [[ -n "$GOT_IP" ]] && break
        echo "  ...attesa (${WAITED}s)"
    done

    echo ""
    if [[ -n "$GOT_IP" ]]; then
        echo "✓ VERIFICA SUPERATA"
        echo "  Il backup '${VM} @ ${TS}' è avviabile."
        echo "  La VM di prova ha bootato e ottenuto IP ${GOT_IP} in ${WAITED}s."
        RESULT=0
    else
        echo "✗ VERIFICA FALLITA"
        echo "  La VM di prova si è definita ma non ha preso un IP entro 120s."
        echo "  Il backup potrebbe avere un problema di boot o di rete."
        RESULT=1
    fi

    echo ""
    echo "→ Rimuovo la VM di prova..."
    # la pulizia avviene comunque via trap EXIT
    exit $RESULT

# [VM Manager] Programma il backup automatico notturno delle VM
vm-backup-schedule ORARIO="" VERSIONI="2":
    #!/usr/bin/env bash
    set -uo pipefail
    export LC_ALL=C

    BACKUP_ROOT="/var/mnt/backup"
    SERVICE="/etc/systemd/system/atomik-vm-backup.service"
    TIMER="/etc/systemd/system/atomik-vm-backup.timer"

    ORARIO="{{ORARIO}}"
    VERSIONI="{{VERSIONI}}"

    echo "┌────────────────────────────────────────────────┐"
    echo "  Backup automatico VM — programmazione          "
    echo "└────────────────────────────────────────────────┘"
    echo ""

    # ── Orario: da parametro o chiesto (default 03:00) ───────────────────────
    if [[ -z "$ORARIO" ]]; then
        read -rp "Orario del backup giornaliero [03:00]: " ORARIO
        ORARIO="${ORARIO:-03:00}"
    fi

    # Valida il formato HH:MM
    if ! [[ "$ORARIO" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        echo "✗ Orario non valido: '${ORARIO}'. Usa il formato HH:MM (es. 03:00)."
        exit 1
    fi

    # ── Verifica che il mount di backup esista come unit systemd ─────────────
    # Il backup scrive su /var/mnt/backup: il service deve dipendere da quel
    # mount, così non parte (e non fallisce) se il NAS non è disponibile.
    MOUNT_UNIT="$(systemd-escape --path --suffix=mount "$BACKUP_ROOT")"
    if ! systemctl list-unit-files "$MOUNT_UNIT" &>/dev/null \
        && [[ ! -f "/etc/systemd/system/${MOUNT_UNIT}" ]]; then
        echo "⚠ Il mount di backup (${MOUNT_UNIT}) non risulta configurato."
        echo "  Configura prima lo share NAS con:  ujust smb-system backup"
        echo "  Il backup automatico ha bisogno di ${BACKUP_ROOT} per scrivere."
        echo ""
        read -rp "Procedo comunque? [s/N]: " GOAHEAD
        [[ "${GOAHEAD,,}" != "s" ]] && { echo "Operazione annullata."; exit 0; }
    fi

    echo ""
    echo "→ Configurazione:"
    echo "  Orario:    ${ORARIO} (ogni giorno)"
    echo "  Versioni:  ${VERSIONI} per VM"
    echo "  Comando:   ujust vm-backup \"\" ${VERSIONI}"
    echo "  Dipende da: ${MOUNT_UNIT}"
    echo ""
    read -rp "Confermi? [s/N]: " CONFIRM
    [[ "${CONFIRM,,}" != "s" ]] && { echo "Operazione annullata."; exit 0; }

    # ── Service: esegue vm-backup su tutte le VM ─────────────────────────────
    # Requires+After sul mount: se il NAS non è montato, il service non parte.
    printf '%s\n' \
        "[Unit]" \
        "Description=Atomik — backup automatico delle VM" \
        "Requires=${MOUNT_UNIT}" \
        "After=${MOUNT_UNIT}" \
        "" \
        "[Service]" \
        "Type=oneshot" \
        "ExecStart=/usr/bin/ujust vm-backup \"\" ${VERSIONI}" \
        | sudo tee "$SERVICE" > /dev/null

    # ── Timer: ogni giorno all'orario scelto ─────────────────────────────────
    # Persistent=true: se l'hypervisor era spento all'ora prevista, il backup
    # parte al successivo avvio (non salta il giorno).
    printf '%s\n' \
        "[Unit]" \
        "Description=Atomik — backup automatico delle VM" \
        "Requires=${MOUNT_UNIT}" \
        "After=${MOUNT_UNIT}" \
        "" \
        "[Service]" \
        "Type=oneshot" \
        "Environment=HOME=/root" \
        "ExecStart=/usr/bin/ujust vm-backup '' ${VERSIONI}" \
        | sudo tee "$SERVICE" > /dev/null

    sudo systemctl daemon-reload
    sudo systemctl enable --now atomik-vm-backup.timer

    echo ""
    echo "✓ Backup automatico programmato ogni giorno alle ${ORARIO}."
    echo ""
    echo "  Prossima esecuzione:  systemctl list-timers atomik-vm-backup.timer"
    echo "  Esecuzione manuale:   sudo systemctl start atomik-vm-backup.service"
    echo "  Log dell'ultimo run:  /var/mnt/backup/log/ (e log_errori/ se problemi)"
    echo "  Disattiva con:        ujust vm-backup-unschedule"

# [VM Manager] Disattiva il backup automatico notturno delle VM
vm-backup-unschedule:
    #!/usr/bin/env bash
    set -uo pipefail

    SERVICE="/etc/systemd/system/atomik-vm-backup.service"
    TIMER="/etc/systemd/system/atomik-vm-backup.timer"

    if [[ ! -f "$TIMER" ]]; then
        echo "Il backup automatico non è configurato."
        exit 0
    fi

    sudo systemctl disable --now atomik-vm-backup.timer 2>/dev/null || true
    sudo rm -f "$TIMER" "$SERVICE"
    sudo systemctl daemon-reload

    echo "✓ Backup automatico disattivato e rimosso."
    echo "  (i backup già presenti sul NAS restano intatti)"
