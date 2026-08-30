#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════╗
# ║  Atomik OS — Installer bootstrap                        ║
# ║  Scarica, verifica (GPG + SHA256) ed esegue il wizard   ║
# ║                                                         ║
# ║  Uso: curl -fsSL https://tuosito.com/get-atomik.sh | bash ║
# ╚══════════════════════════════════════════════════════════╝
set -euo pipefail

# ── Configurazione ────────────────────────────────────────
REPO_RAW="https://raw.githubusercontent.com/giurest/atomik-os/main"
PUBKEY_URL="https://www.giurestlabs.it/atomik-os/pubkey.gpg"   # <── aggiorna con il tuo sito
SCRIPT_URL="$REPO_RAW/install/atomik-install.sh"
SIG_URL="$REPO_RAW/install/atomik-install.sh.asc"
SHA_URL="$REPO_RAW/install/atomik-install.sh.sha256"

# ── Colori ───────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*" >&2; }
info() { echo -e "${YELLOW}→${NC} $*"; }

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

# ── Verifica SHA256 ──────────────────────────────────────
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

# ── Verifica firma GPG (keyring temporaneo isolato) ──────
info "Verifica firma GPG dal sito..."
export GNUPGHOME
gpg --batch --quiet --import "$TMPDIR/pubkey.gpg" 2>/dev/null || {
    err "Impossibile importare la chiave pubblica."
    exit 1
}
gpg --batch --quiet --verify \
    "$TMPDIR/atomik-install.sh.asc" \
    "$TMPDIR/atomik-install.sh" 2>/dev/null || {
    err "Verifica firma GPG fallita."
    err "Il file potrebbe essere stato manomesso."
    err "Installazione negata per sicurezza."
    exit 1
}
ok "Firma GPG verificata"
echo ""

# ── Esegui il wizard ─────────────────────────────────────
bash "$TMPDIR/atomik-install.sh"
