# ═══════════════════════════════════════════════════════════════════════════════
#  Atomik OS — entrypoint puregaming
#  Copiato come /usr/share/atomik/justfile nelle immagini puregaming e
#  puregaming-nvidia. Compone i moduli desktop + gaming.
# ═══════════════════════════════════════════════════════════════════════════════

import 'common.just'
import 'environment.just'
import 'desktop-tools.just'
import 'gaming.just'

# Mostra l'elenco delle ricette disponibili
_default:
    @just --list --unsorted --justfile {{justfile()}}
