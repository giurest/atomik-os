# Atomik OS — Variante Desktop

> 🚧 Documentazione in elaborazione

La variante **desktop** è la base da cui ereditano tutte le altre varianti. È progettata per workstation personali su hardware AMD/Intel.

## Caratteristiche

- **Desktop**: KDE Plasma 6 (Breeze Dark, profilo Fast)
- **Shell**: Fish + Starship
- **Browser**: Brave (nativo, debloated)
- **Terminal**: Konsole con profilo Atomik
- **Package manager utente**: Homebrew
- **App**: Flatpak via Bazaar/Flathub

## Installazione

```bash
curl -fsSL https://giurestlabs.it/get-atomik | bash
# → scegli "desktop"
```

## Ricette ujust principali

```bash
ujust update           # aggiorna il sistema
ujust status           # stato immagine bootc
ujust rollback         # torna all'immagine precedente
ujust brew-setup       # installa Homebrew
ujust sshauth-config   # configura SSH verso l'hypervisor
ujust vm-console VM    # apre la console SPICE di una VM
```

---

*Per la guida completa all'installazione, vedi il [README principale](../README.md).*
