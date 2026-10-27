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
### Principio di funzionamento ujust
Ogni Variante ha un entrypoint-variante.just che viene caricato come loader specifico, all'interno del file vengono importate le ricette provenienti dal catalogo specifico se prendiamo in esame entrypoint-desktop.just troveremo al suo interno:
-desktop-tools.just
-environment.just
-ollama.just

```bash
ujust update           # aggiorna il sistema
ujust status           # stato immagine bootc
ujust rollback         # torna all'immagine precedente
ujust brew-setup       # installa Homebrew
ujust sshauth-config   # configura SSH verso l'hypervisor
ujust vm-console VM    # apre la console SPICE di una VM
ujust ollama-setup     # Ollama + Open WebUI in Podman (vedi docs/ollama.md)
```

## Varianti NVIDIA e Secure Boot

Il driver NVIDIA proprietario non è firmato per Secure Boot. Per usarlo,
disattiva Secure Boot nel firmware: con Secure Boot attivo il sistema si avvia
comunque, ma con il driver grafico di base.

---

*Per la guida completa all'installazione, vedi il [README principale](../README.md).*
