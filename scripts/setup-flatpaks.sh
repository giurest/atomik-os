#!/usr/bin/env bash
# ── Atomik OS — Setup Flatpak apps ───────────────────────────────────────────
# Eseguire dopo il primo boot per installare le app via Flatpak
# Uso: bash setup-flatpaks.sh [desktop|puregaming|handheld]

set -euo pipefail

VARIANT="${1:-desktop}"

echo "🔧 Atomik OS — installazione Flatpak per variante: $VARIANT"

# Aggiunge Flathub se non presente
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# ── App comuni a tutte le varianti ────────────────────────────────────────────
COMMON_APPS=(
    "com.brave.Browser"
)

# ── App variante Desktop ──────────────────────────────────────────────────────
DESKTOP_APPS=(
    "com.vscodium.codium"
    "com.github.bh3nk.gitfiend"
    "org.onlyoffice.desktopeditors"
    "org.gnome.Nautilus"
    "org.gnome.Loupe"
    "org.gnome.TextEditor"
    "com.obsproject.Studio"
)

# ── App variante PureGaming ───────────────────────────────────────────────────
GAMING_APPS=(
    "com.heroicgameslauncher.hgl"
    "net.lutris.Lutris"
    "com.github.Matoking.protontricks"
    "io.github.benjamimgois.goverlay"
    "net.davidotek.pupgui2"
)

# ── App variante Handheld ─────────────────────────────────────────────────────
HANDHELD_APPS=(
    "com.heroicgameslauncher.hgl"
    "net.lutris.Lutris"
)

install_apps() {
    local apps=("$@")
    for app in "${apps[@]}"; do
        echo "  📦 Installazione $app..."
        flatpak install --noninteractive flathub "$app" || \
            echo "  ⚠️  $app non trovato, saltato"
    done
}

echo "📦 Installazione app comuni..."
install_apps "${COMMON_APPS[@]}"

case "$VARIANT" in
    desktop)
        echo "📦 Installazione app Desktop..."
        install_apps "${DESKTOP_APPS[@]}"
        ;;
    puregaming|puregaming-nvidia)
        echo "📦 Installazione app Gaming..."
        install_apps "${GAMING_APPS[@]}"
        ;;
    handheld)
        echo "📦 Installazione app Handheld..."
        install_apps "${HANDHELD_APPS[@]}"
        ;;
    *)
        echo "⚠️  Variante '$VARIANT' non riconosciuta, installazione solo app comuni"
        ;;
esac

echo "✅ Flatpak setup completato per variante: $VARIANT"
