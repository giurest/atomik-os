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
