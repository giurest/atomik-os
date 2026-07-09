# ═══════════════════════════════════════════════════════════════════════════════
#  Atomik OS — hypervisor.just
#  Funzioni specifiche delal variante Hypervisor. 
#  Importato via `import` dal justfile entrypoint-hypervisor.just.
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# Gestione Macchine virtuali
# ─────────────────────────────────────────────────────────────────────────────

# [VM Manager] Elenca tutte le VM definite (attive e spente)
vm-list:
    @sudo virsh list --all