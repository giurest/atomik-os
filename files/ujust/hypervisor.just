# Atomik OS — ricette specifiche Hypervisor (caricato solo su atomik-hypervisor)
# Importato via `import?` dal justfile condiviso; il file esiste solo
# nell'immagine hypervisor, quindi queste ricette non appaiono sulle altre varianti.
import? 'common.just'
import? 'environment.just'

# ─────────────────────────────────────────────────────────────────────────────
# Hypervisor — Gestione VM
# ─────────────────────────────────────────────────────────────────────────────

# [Hypervisor - VM Manager] Elenca tutte le VM definite (attive e spente)
vm-list:
    @sudo virsh list --all
