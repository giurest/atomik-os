#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════╗
# ║  Atomik OS — Installer bootstrap                        ║
# ║  Scarica, verifica (GPG + SHA256) ed esegue il wizard   ║
# ║                                                         ║
# ║  Uso: curl -fsSL https://giurestlabs.it/get-atomik | bash ║
# ╚══════════════════════════════════════════════════════════╝
#
# Modello di fiducia: questo script è servito da giurestlabs.it (non da GitHub)
# e accetta solo un installer firmato dalla chiave con la fingerprint qui sotto.
# Se cambi chiave GPG, aggiorna EXPECTED_FPR e ripubblica questo file sul sito.
set -euo pipefail

# ── Configurazione ────────────────────────────────────────
REPO_RAW="https://raw.githubusercontent.com/giurest/atomik-os/main"
PUBKEY_URL="https://www.giurestlabs.it/atomik-os/pubkey.gpg"
SCRIPT_URL="$REPO_RAW/install/atomik-install.sh"
SIG_URL="$REPO_RAW/install/atomik-install.sh.asc"
SHA_URL="$REPO_RAW/install/atomik-install.sh.sha256"
# Fingerprint della chiave di firma (pubblicata anche in README, SECURITY.md e sul sito)
EXPECTED_FPR="08B4032AE9794BFB8F5ACD90BE35CB1EBF3CAD73"

# ── Colori ───────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*" >&2; }
info() { echo -e "${YELLOW}→${NC} $*"; }

# Fingerprint a gruppi di 4, come nel README: 5 gruppi, doppio spazio, 5 gruppi.
fpr_pretty() {
    local s="$1" out="" i
    for ((i = 0; i < ${#s}; i += 4)); do
        out+="${s:i:4} "
        [ "$i" -eq 16 ] && out+=" "
    done
    echo "${out% }"
}

# ── Prerequisiti ─────────────────────────────────────────
for cmd in curl gpg sha256sum; do
    command -v "$cmd" &>/dev/null || {
        err "Prerequisito mancante: $cmd"
        exit 1
    }
done

echo ""
echo "  Atomik OS — Verifica integrità installer"
echo "  ─────────────────────────────────────────"
echo ""

# ── Directory temporanea (pulizia automatica) ────────────
TMPDIR=$(mktemp -d /tmp/atomik-XXXX)
GNUPGHOME=$(mktemp -d /tmp/atomik-gpg-XXXX)
cleanup() { rm -rf "$TMPDIR" "$GNUPGHOME"; }
trap cleanup EXIT

# ── Download ─────────────────────────────────────────────
info "Download installer..."
curl -fsSL "$SCRIPT_URL" -o "$TMPDIR/atomik-install.sh" || {
    err "Impossibile scaricare l'installer."
    exit 1
}
curl -fsSL "$SIG_URL"    -o "$TMPDIR/atomik-install.sh.asc" || {
    err "Impossibile scaricare la firma."
    exit 1
}
curl -fsSL "$SHA_URL"    -o "$TMPDIR/atomik-install.sh.sha256" || {
    err "Impossibile scaricare il checksum."
    exit 1
}
curl -fsSL "$PUBKEY_URL" -o "$TMPDIR/pubkey.gpg" || {
    err "Impossibile raggiungere $PUBKEY_URL"
    err "Verifica la connessione o contatta il maintainer."
    exit 1
}

# ── Verifica SHA256 (integrità del download, non è una misura di sicurezza) ──
info "Verifica SHA256..."
EXPECTED_SHA=$(cat "$TMPDIR/atomik-install.sh.sha256" | awk '{print $1}')
ACTUAL_SHA=$(sha256sum "$TMPDIR/atomik-install.sh" | awk '{print $1}')
if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
    err "Verifica SHA256 fallita."
    err "  Atteso:  $EXPECTED_SHA"
    err "  Trovato: $ACTUAL_SHA"
    err "Installazione negata per sicurezza."
    exit 1
fi
ok "SHA256 verificato"

# ── Verifica firma GPG (keyring temporaneo isolato, chiave fissata) ──────
info "Verifica firma GPG (chiave fissata)..."
export GNUPGHOME
if ! gpg --batch --quiet --import "$TMPDIR/pubkey.gpg" 2>"$TMPDIR/gpg-import.log"; then
    err "Impossibile importare la chiave pubblica."
    sed 's/^/    /' "$TMPDIR/gpg-import.log" >&2
    exit 1
fi

# Il keyring deve contenere UNA sola chiave primaria, quella attesa.
FOUND_FPRS=$(gpg --batch --with-colons --list-keys 2>/dev/null \
    | awk -F: '/^pub:/ {p=1} /^fpr:/ && p {print $10; p=0}')
if [ "$FOUND_FPRS" != "$EXPECTED_FPR" ]; then
    err "La chiave scaricata non corrisponde alla fingerprint attesa."
    err "  Attesa:  $EXPECTED_FPR"
    err "  Trovata: ${FOUND_FPRS:-(nessuna)}"
    err "Installazione negata per sicurezza."
    exit 1
fi

# La firma deve essere stata prodotta proprio da quella chiave.
if ! VERIFY_STATUS=$(gpg --batch --status-fd 1 --verify \
        "$TMPDIR/atomik-install.sh.asc" \
        "$TMPDIR/atomik-install.sh" 2>"$TMPDIR/gpg-verify.log"); then
    err "Verifica firma GPG fallita."
    sed 's/^/    /' "$TMPDIR/gpg-verify.log" >&2
    err "Il file potrebbe essere stato manomesso."
    err "Installazione negata per sicurezza."
    exit 1
fi
SIGNER_FPR=$(printf '%s\n' "$VERIFY_STATUS" \
    | awk '/^\[GNUPG:\] VALIDSIG / {print $NF; exit}')
if [ "$SIGNER_FPR" != "$EXPECTED_FPR" ]; then
    err "La firma non è stata prodotta dalla chiave attesa."
    err "  Attesa:  $EXPECTED_FPR"
    err "  Trovata: ${SIGNER_FPR:-(nessuna)}"
    err "Installazione negata per sicurezza."
    exit 1
fi
ok "Firma GPG verificata"
echo ""
echo "  Chiave di firma:"
echo "    $(fpr_pretty "$EXPECTED_FPR")"
echo "  (confrontala con quella pubblicata nel README e in SECURITY.md)"
echo ""
# Il wizard cancella lo schermo: aspetto un INVIO così l'esito resta leggibile.
read -r -p "  Premi INVIO per avviare l'installazione (Ctrl+C per annullare)... " _ < /dev/tty || true

# ── Esegui il wizard ─────────────────────────────────────
exec bash "$TMPDIR/atomik-install.sh" < /dev/tty > /dev/tty 2>&1
