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
- **desktop-tools.just**
- **environment.just**
- **ollama.just**

```bash
ujust update           # aggiorna il sistema
ujust changelog        # Mostra cosa è cambiato dopo l'ultimo aggiornamento (da usare dopo ujust update)
ujust status           # stato immagine bootc
ujust bench            # Benchmark interno al sistema
ujust rollback         # torna all'immagine precedente
ujust brew-setup       # installa Homebrew
ujust sshauth-config   # configura SSH verso l'hypervisor
ujust vm-console VM    # apre la console SPICE di una VM (Da usare in aggiunta ad un istanza Hypervisor installata sulla rete)
ujust ollama-setup     # Ollama + Open WebUI in Podman (vedi docs/ollama.md)
ujust install-winboat  # Installa WinBoat (Windows app runner via container)
ujust unlock-winboat   # Sblocca WinBoat (riavvia il container)
ujust powerwash        # Powerwash: backup dati essenziali + reset completo del sistema (Serve un disco esterno)
ujust create-user      # Crea un nuovo utente con home e shell, aggiunto al gruppo wheel (sudo)
ujust delete-user      # Elimina un utente esistente (opzionalmente con la sua home)
ujust passwd-user      # Cambia la password di un utente
ujust toggle-sudo      # Aggiungi o rimuovi i privilegi sudo (gruppo wheel) per un utente
ujust list-users       # Elenca gli utenti umani del sistema (UID >= 1000)


```

## Varianti NVIDIA e Secure Boot

Il driver NVIDIA proprietario non è firmato per Secure Boot. Per usarlo,
disattiva Secure Boot nel firmware: con Secure Boot attivo il sistema si avvia
comunque, ma con il driver grafico di base.

---

*Per la guida completa all'installazione, vedi il [README principale](../README.md).*
