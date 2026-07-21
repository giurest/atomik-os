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
    
# [VM Manager] Crea una nuova VM Atomik Server
atomik-server:
    #!/usr/bin/env bash
    set -euo pipefail

    BASE_DIR="/var/lib/libvirt/images/base"
    BASE_IMG="${BASE_DIR}/atomik-server.qcow2"
    BASE_URL="https://github.com/giurest/atomik-os/releases/download/server-latest/atomik-server.qcow2"
    IMAGES_DIR="/var/lib/libvirt/images"
    BOOT_DIR="/var/lib/libvirt/boot"
    TEMPLATE="/usr/share/atomik/cloud-init/user-data.template"

    echo "═══ Crea VM Atomik Server ═══"
    echo ""

    # ── Parametri interattivi ────────────────────────────────────────────────
    read -rp "Nome della VM [atomik-vm]: " VM_NAME
    VM_NAME="${VM_NAME:-atomik-vm}"

    read -rp "Username nella VM [giurest]: " VM_USER
    VM_USER="${VM_USER:-giurest}"

    read -rp "RAM in MB [2048]: " VM_RAM
    VM_RAM="${VM_RAM:-2048}"

    read -rp "vCPU [2]: " VM_CPU
    VM_CPU="${VM_CPU:-2}"

    # ── Verifica che la VM non esista gia' ───────────────────────────────────
    if sudo virsh dominfo "$VM_NAME" &>/dev/null; then
        echo "✗ Una VM chiamata '$VM_NAME' esiste gia'. Scegli un altro nome."
        exit 1
    fi

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

    # ── Seed cloud-init (NoCloud: label CIDATA, nomi user-data/meta-data) ─────
    echo "→ Genero il seed cloud-init..."
    (cd "$WORKDIR" && xorriso -as mkisofs -o seed.iso -V CIDATA -J -r user-data meta-data 2>/dev/null)
    sudo cp "${WORKDIR}/seed.iso" "${BOOT_DIR}/${VM_NAME}-seed.iso"
    sudo restorecon "${BOOT_DIR}/${VM_NAME}-seed.iso"

    # ── Disco VM: copia piena dell'immagine base ─────────────────────────────
    echo "→ Copio l'immagine base nel disco della VM..."
    sudo cp "$BASE_IMG" "${IMAGES_DIR}/${VM_NAME}.qcow2"
    sudo restorecon "${IMAGES_DIR}/${VM_NAME}.qcow2"

    # ── Creazione della VM ───────────────────────────────────────────────────
    echo "→ Creo la VM..."
    sudo virt-install --name "$VM_NAME" \
        --memory "$VM_RAM" --vcpus "$VM_CPU" \
        --disk "${IMAGES_DIR}/${VM_NAME}.qcow2,format=qcow2" \
        --disk "${BOOT_DIR}/${VM_NAME}-seed.iso,device=cdrom" \
        --import --os-variant fedora-unknown \
        --network network=default \
        --graphics none --noautoconsole

    # ── Attesa indirizzo IP ──────────────────────────────────────────────────
    echo "→ Attendo l'avvio della VM..."
    VM_IP=""
    for _ in $(seq 1 30); do
        sleep 3
        VM_IP="$(sudo virsh domifaddr "$VM_NAME" 2>/dev/null | awk '/ipv4/ {print $4}' | cut -d/ -f1)"
        [[ -n "$VM_IP" ]] && break
    done

    echo ""
    if [[ -n "$VM_IP" ]]; then
        echo "✓ VM '$VM_NAME' creata e avviata"
        echo ""
        echo "  Accesso:  ssh ${VM_USER}@${VM_IP}"
        echo "  Password: ${VM_USER}  (dovrai cambiarla al primo accesso)"
    else
        echo "✓ VM '$VM_NAME' creata"
        echo "  L'indirizzo IP non e' ancora disponibile. Riprova tra poco con:"
        echo "    sudo virsh domifaddr $VM_NAME"
    fi
    echo ""
    echo "  Console:  sudo virsh console $VM_NAME   (Ctrl+] per uscire)"
    echo "  Rimuovi:  ujust vm-delete"

# [VM Manager] Rimuove una VM e il suo storage
vm-delete:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "VM definite:"
    sudo virsh list --all
    echo ""
    read -rp "Nome della VM da rimuovere: " VM_NAME
    [[ -z "$VM_NAME" ]] && { echo "Nessun nome fornito."; exit 1; }

    if ! sudo virsh dominfo "$VM_NAME" &>/dev/null; then
        echo "✗ La VM '$VM_NAME' non esiste."
        exit 1
    fi
    echo "ATTENZIONE: Questa procedura è irreversibile se si procede non ci sarà più modo di recuperare i dati al suo interno." 	
    read -rp "Rimuovere '$VM_NAME' e TUTTI i suoi dischi? [s/N]: " CONFIRM
    [[ "${CONFIRM,,}" != "s" ]] && { echo "Operazione annullata."; exit 0; }

    sudo virsh destroy "$VM_NAME" 2>/dev/null || true
    sudo virsh undefine "$VM_NAME" --remove-all-storage
    sudo rm -f "/var/lib/libvirt/boot/${VM_NAME}-seed.iso"
    echo "✓ VM '$VM_NAME' rimossa"    

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