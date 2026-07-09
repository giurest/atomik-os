# ═══════════════════════════════════════════════════════════════════════════════
#  Atomik OS — entrypoint desktop
#  Copiato come /usr/share/atomik/justfile nell'immagine desktop.
#  Compone i moduli per la variante desktop (e desktop-nvidia, che eredita).
# ═══════════════════════════════════════════════════════════════════════════════

import 'common.just'
import 'environment.just'
import 'desktop-tools.just'

# Mostra l'elenco delle ricette disponibili
_default:
    @just --list --unsorted --justfile {{justfile()}}
