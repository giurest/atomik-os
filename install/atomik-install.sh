#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════╗
# ║  Atomik OS — Wizard di installazione                    ║
# ║  Verificato da get-atomik.sh prima dell'esecuzione      ║
# ╚══════════════════════════════════════════════════════════╝
set -euo pipefail

REGISTRY="ghcr.io/giurest"

# ── Colori ───────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*" >&2; }
info() { echo -e "${YELLOW}→${NC} $*"; }

# ── Verifica prerequisiti ────────────────────────────────
check_prerequisites() {
    echo ""
    info "Verifica prerequisiti..."

    # bootc installato?
    command -v bootc &>/dev/null || {
        err "bootc non trovato. Questo installer richiede un sistema bootc-compatibile."
        err "Installa Fedora Kinoite e riprova."
        exit 1
    }
    ok "bootc presente"

    # Sistema compatibile? (Fedora / bootc)
    local os_id
    os_id=$(grep "^ID=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    local variant_id
    variant_id=$(grep "^VARIANT_ID=" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')

    if [[ "$os_id" != "fedora" ]]; then
        err "Sistema non supportato: $os_id. Richiesto: Fedora."
        exit 1
    fi
    ok "Sistema Fedora rilevato"

    # Già su Atomik?
    local image_name
    image_name=$(bootc status --json 2>/dev/null \
        | python3 -c "import json,sys; s=json.load(sys.stdin); \
          print(s.get('status',{}).get('booted',{}).get('image',{}).get('image',{}).get('image',''))" \
          2>/dev/null || echo "")

    if echo "$image_name" | grep -q "giurest/atomik"; then
        err "Questo sistema è già su Atomik OS ($image_name)."
        err "Per aggiornare usa: ujust update"
        exit 1
    fi
    ok "Sistema pronto per l'installazione"

    # Connettività a ghcr.io?
    info "Verifica connettività a ghcr.io..."
    curl -fsSL --connect-timeout 5 "https://ghcr.io" &>/dev/null || {
        err "Impossibile raggiungere ghcr.io. Verifica la connessione."
        exit 1
    }
    ok "Connettività OK"
    echo ""
}

# ── Scelta variante (whiptail) ───────────────────────────
choose_variant() {
    if ! command -v whiptail &>/dev/null; then
        # Fallback testuale se whiptail non disponibile
        echo -e "${BOLD}Seleziona la variante Atomik OS:${NC}"
        echo ""
        echo "  1) Desktop           — Workstation generale (AMD/Intel)"
        echo "  2) Desktop NVIDIA    — Workstation con GPU NVIDIA"
        echo "  3) PureGaming        — Gaming ottimizzato (AMD/Intel)"
        echo "  4) PureGaming NVIDIA — Gaming ottimizzato con GPU NVIDIA"
        echo "  5) Hypervisor        — Server di virtualizzazione (headless)"
        echo ""
        read -rp "Scelta [1-5]: " choice
        case "$choice" in
            1) VARIANT="atomik-desktop" ;;
            2) VARIANT="atomik-desktop-nvidia" ;;
            3) VARIANT="atomik-puregaming" ;;
            4) VARIANT="atomik-puregaming-nvidia" ;;
            5) VARIANT="atomik-hypervisor" ;;
            *) err "Scelta non valida."; exit 1 ;;
        esac
    else
        VARIANT=$(whiptail --title "Atomik OS — Selezione variante" \
            --menu "Seleziona la variante da installare:" 20 70 5 \
            "atomik-desktop"          "Desktop           — Workstation generale (AMD/Intel)" \
            "atomik-desktop-nvidia"   "Desktop NVIDIA    — Workstation con GPU NVIDIA" \
            "atomik-puregaming"       "PureGaming        — Gaming ottimizzato (AMD/Intel)" \
            "atomik-puregaming-nvidia" "PureGaming NVIDIA — Gaming ottimizzato con GPU NVIDIA" \
            "atomik-hypervisor"       "Hypervisor        — Server di virtualizzazione (headless)" \
            3>&1 1>&2 2>&3) || {
            err "Installazione annullata."
            exit 0
        }
    fi
}

# ── Conferma ─────────────────────────────────────────────
confirm_install() {
    local image="$REGISTRY/$VARIANT:latest"
    if command -v whiptail &>/dev/null; then
        whiptail --title "Atomik OS — Conferma" --yesno \
"Stai per installare:

  Variante : $VARIANT
  Immagine : $image

Il sistema verrà modificato tramite bootc switch.
I tuoi dati in /home e /var saranno preservati.
Al termine ti verrà chiesto di riavviare.

Continuare?" 16 65 || {
            err "Installazione annullata."
            exit 0
        }
    else
        echo ""
        echo -e "${BOLD}Riepilogo installazione:${NC}"
        echo "  Variante : $VARIANT"
        echo "  Immagine : $image"
        echo ""
        read -rp "Continuare? [y/N]: " confirm
        [[ "${confirm,,}" == "y" ]] || { err "Installazione annullata."; exit 0; }
    fi
}

# ── Switch ───────────────────────────────────────────────
do_switch() {
    local image="$REGISTRY/$VARIANT:latest"
    echo ""
    info "Avvio installazione di $VARIANT..."
    info "Questo richiederà alcuni minuti (download ~2-4 GB)."
    echo ""
    sudo bootc switch "$image" || {
        err "bootc switch fallito."
        err "Verifica i log con: sudo journalctl -u bootc"
        exit 1
    }
}

# ── Completamento ────────────────────────────────────────
finish() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Atomik OS installato con successo!          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Variante : ${BOLD}$VARIANT${NC}"
    echo ""
    echo "  Al primo avvio dopo il riavvio:"
    echo "  • Le app Flatpak verranno installate automaticamente"
    echo "  • La configurazione del desktop verrà applicata"
    echo "  • Usa 'ujust' per scoprire le funzionalità disponibili"
    echo ""

    # Countdown riavvio
    echo -e "${YELLOW}  Il sistema si riavvierà tra 15 secondi.${NC}"
    echo -e "  Premi ${BOLD}Ctrl+C${NC} per annullare il riavvio."
    echo ""
    for i in $(seq 15 -1 1); do
        printf "\r  Riavvio in %2d secondi..." "$i"
        sleep 1
    done
    echo ""
    sudo systemctl reboot
}

# ── Main ─────────────────────────────────────────────────
clear
echo ""
echo -e "${BLUE}${BOLD}"
echo "    █████╗ ████████╗ ██████╗ ███╗   ███╗██╗██╗  ██╗"
echo "   ██╔══██╗╚══██╔══╝██╔═══██╗████╗ ████║██║██║ ██╔╝"
echo "   ███████║   ██║   ██║   ██║██╔████╔██║██║█████╔╝ "
echo "   ██╔══██║   ██║   ██║   ██║██║╚██╔╝██║██║██╔═██╗ "
echo "   ██║  ██║   ██║   ╚██████╔╝██║ ╚═╝ ██║██║██║  ██╗"
echo "   ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝     ╚═╝╚═╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "   ${BOLD}Immutable. Minimal. Yours.${NC}"
echo ""
echo "   Installer — $(date +%Y)"
echo ""

check_prerequisites
choose_variant
confirm_install
do_switch
finish
