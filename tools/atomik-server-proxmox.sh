#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  Atomik Server — provisioning VM su Proxmox
#  Crea una VM atomik-server scaricando il qcow2 dalla release "server-latest",
#  importandolo, configurando UEFI e cloud-init (utente + password hashata).
#
#  Uso (sul nodo Proxmox, come root):
#    bash -c "$(curl -fsSL https://raw.githubusercontent.com/giurest/atomik-os/main/tools/atomik-server-proxmox.sh)"
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

QCOW2_URL="https://github.com/giurest/atomik-os/releases/download/server-latest/atomik-server.qcow2"

# ── Colori ───────────────────────────────────────────────────────────────────
C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_GREEN=$'\e[1;32m'; C_BLUE=$'\e[1;34m'
C_YELLOW=$'\e[1;33m'; C_RED=$'\e[1;31m'

info()  { echo "${C_BLUE}→${C_RESET} $*"; }
ok()    { echo "${C_GREEN}✓${C_RESET} $*"; }
warn()  { echo "${C_YELLOW}⚠${C_RESET} $*"; }
err()   { echo "${C_RED}✗${C_RESET} $*" >&2; }

# Chiede con default: ask VAR "Domanda" "default"
ask() {
    local __var="$1" __prompt="$2" __default="${3:-}" __reply
    if [ -n "$__default" ]; then
        read -rp "$(printf '%s [%s]: ' "$__prompt" "$__default")" __reply
        __reply="${__reply:-$__default}"
    else
        read -rp "$(printf '%s: ' "$__prompt")" __reply
    fi
    printf -v "$__var" '%s' "$__reply"
}

# ── Verifiche preliminari ────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    err "Esegui come root sul nodo Proxmox."
    exit 1
fi
for cmd in qm pvesm pvesh openssl curl; do
    command -v "$cmd" >/dev/null || { err "Comando mancante: $cmd (sei su un nodo Proxmox?)"; exit 1; }
done

echo ""
echo "${C_BOLD}┌────────────────────────────────────────────┐${C_RESET}"
echo "${C_BOLD}│  Atomik Server — provisioning VM Proxmox   │${C_RESET}"
echo "${C_BOLD}└────────────────────────────────────────────┘${C_RESET}"
echo ""

# ── Default rilevati ─────────────────────────────────────────────────────────
DEF_VMID="$(pvesh get /cluster/nextid 2>/dev/null || echo 100)"
# Primo storage che supporta 'images' (per il disco)
DEF_STORAGE="$(pvesm status -content images 2>/dev/null | awk 'NR==2{print $1}')"
DEF_STORAGE="${DEF_STORAGE:-local-lvm}"
# Storage che supporta 'snippets' (per il cloud-init custom)
DEF_SNIPSTORE="$(pvesm status -content snippets 2>/dev/null | awk 'NR==2{print $1}')"
DEF_SNIPSTORE="${DEF_SNIPSTORE:-local}"
# Primo bridge di rete
DEF_BRIDGE="$(ip -o link show 2>/dev/null | awk -F': ' '/vmbr/{print $2; exit}')"
DEF_BRIDGE="${DEF_BRIDGE:-vmbr0}"

# ── Raccolta parametri ───────────────────────────────────────────────────────
ask VMID       "VMID"                       "$DEF_VMID"
ask VMNAME     "Nome VM"                     "atomik-server"
ask HOSTNAME   "Hostname"                    "$VMNAME"
ask CORES      "Core CPU"                    "2"
ask MEMORY     "RAM (MB)"                    "4096"
ask DISKSIZE   "Dimensione disco aggiuntiva (GB, 0 = nessuna)" "0"
ask STORAGE    "Storage disco"               "$DEF_STORAGE"
ask SNIPSTORE  "Storage snippets (cloud-init)" "$DEF_SNIPSTORE"
ask BRIDGE     "Bridge di rete"              "$DEF_BRIDGE"
ask CIUSER     "Utente da creare"            "giurest"

# Password (input nascosto, con conferma)
while true; do
    read -rsp "Password per $CIUSER: " CIPASS; echo ""
    read -rsp "Conferma password: " CIPASS2; echo ""
    if [ "$CIPASS" = "$CIPASS2" ] && [ -n "$CIPASS" ]; then
        break
    fi
    warn "Le password non coincidono o sono vuote, riprova."
done
# Hash SHA-512 della password (non salviamo la password in chiaro)
CIPASS_HASH="$(openssl passwd -6 "$CIPASS")"
unset CIPASS CIPASS2

echo ""
info "Riepilogo:"
echo "    VMID:      $VMID"
echo "    Nome:      $VMNAME  (hostname: $HOSTNAME)"
echo "    Risorse:   ${CORES} core, ${MEMORY} MB RAM"
echo "    Disco:     storage $STORAGE" $([ "$DISKSIZE" != "0" ] && echo "(+${DISKSIZE}GB)")
echo "    Rete:      bridge $BRIDGE (DHCP)"
echo "    Utente:    $CIUSER (password hashata)"
echo ""
ask CONFIRM "Procedo? [s/N]" "N"
[[ "$CONFIRM" =~ ^[sS]$ ]] || { warn "Annullato."; exit 0; }

# ── Download qcow2 ───────────────────────────────────────────────────────────
WORKDIR="$(mktemp -d /tmp/atomik-server-XXXX)"
trap 'rm -rf "$WORKDIR"' EXIT
QCOW2="$WORKDIR/atomik-server.qcow2"
info "Scarico l'immagine disco..."
curl -fSL "$QCOW2_URL" -o "$QCOW2"
ok "Immagine scaricata ($(du -h "$QCOW2" | cut -f1))"

# ── Snippet cloud-init (user-data) con password hashata ──────────────────────
SNIPPET_DIR="/var/lib/vz/snippets"
# Ricava il path reale dello storage snippets se diverso da local
SNIP_PATH="$(pvesm path ${SNIPSTORE}:snippets/placeholder 2>/dev/null | sed 's#/placeholder$##' || true)"
[ -n "$SNIP_PATH" ] && SNIPPET_DIR="$SNIP_PATH"
mkdir -p "$SNIPPET_DIR"
SNIPPET_FILE="atomik-${VMID}-user.yaml"
cat > "${SNIPPET_DIR}/${SNIPPET_FILE}" << CIEOF
#cloud-config
hostname: ${HOSTNAME}
users:
  - name: ${CIUSER}
    groups: [wheel]
    lock_passwd: false
    passwd: "${CIPASS_HASH}"
    shell: /bin/bash
    sudo: ALL=(ALL) ALL
ssh_pwauth: true
chpasswd:
  expire: false
CIEOF
ok "Snippet cloud-init creato: ${SNIPSTORE}:snippets/${SNIPPET_FILE}"

# ── Creazione VM ─────────────────────────────────────────────────────────────
info "Creo la VM $VMID..."
qm create "$VMID" \
    --name "$VMNAME" \
    --memory "$MEMORY" \
    --cores "$CORES" \
    --cpu host \
    --net0 "virtio,bridge=${BRIDGE}" \
    --bios ovmf \
    --machine q35 \
    --scsihw virtio-scsi-pci \
    --ostype l26 \
    --agent enabled=1

# Disco EFI (necessario per UEFI)
info "Configuro UEFI (efidisk)..."
qm set "$VMID" --efidisk0 "${STORAGE}:0,efitype=4m,pre-enrolled-keys=0" >/dev/null

# Importa il qcow2 come disco principale
info "Importo il disco (può richiedere un minuto)..."
qm importdisk "$VMID" "$QCOW2" "$STORAGE" >/dev/null
# Aggancia il disco importato come scsi0
qm set "$VMID" --scsi0 "${STORAGE}:vm-${VMID}-disk-1" >/dev/null 2>&1 \
    || qm set "$VMID" --scsi0 "${STORAGE}:vm-${VMID}-disk-0" >/dev/null

# Espansione disco opzionale
if [ "$DISKSIZE" != "0" ]; then
    info "Espando il disco di +${DISKSIZE}GB..."
    qm resize "$VMID" scsi0 "+${DISKSIZE}G" >/dev/null || warn "Resize non riuscito, ignoro."
fi

# Drive cloud-init + ordine di boot
qm set "$VMID" --ide2 "${STORAGE}:cloudinit" >/dev/null
qm set "$VMID" --boot "order=scsi0" >/dev/null
# Rete DHCP via cloud-init + snippet user-data custom
qm set "$VMID" --ipconfig0 "ip=dhcp" >/dev/null
qm set "$VMID" --cicustom "user=${SNIPSTORE}:snippets/${SNIPPET_FILE}" >/dev/null

ok "VM $VMID creata."

# ── Avvio ────────────────────────────────────────────────────────────────────
ask STARTNOW "Avviare la VM ora? [S/n]" "S"
if [[ ! "$STARTNOW" =~ ^[nN]$ ]]; then
    qm start "$VMID"
    ok "VM avviata."
fi

echo ""
echo "${C_BOLD}┌────────────────────────────────────────────┐${C_RESET}"
echo "${C_BOLD}│  Fatto!                                     │${C_RESET}"
echo "${C_BOLD}└────────────────────────────────────────────┘${C_RESET}"
echo "  VM:       $VMID ($VMNAME)"
echo "  Utente:   $CIUSER"
echo "  Accesso:  ssh ${CIUSER}@<ip-vm>   (IP via DHCP, vedi router o console)"
echo ""
echo "  ${C_YELLOW}Primo accesso:${C_RESET} lancia ${C_BOLD}ujust update${C_RESET} per allineare"
echo "  il sistema all'ultima versione, poi ${C_BOLD}ujust reboot${C_RESET}."
echo ""
