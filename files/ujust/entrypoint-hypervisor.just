# Atomik OS - Hypervisor — system justfile (ujust)
# Eseguito tramite il wrapper `ujust`.

# Configurazione modulare per la variante Hypervisor
import 'hypervisor.just'
import 'common.just'
import 'environment.just'

# Mostra l'elenco delle ricette disponibili
_default:
    @just --list --unsorted --justfile {{justfile()}}