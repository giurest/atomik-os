# Atomik OS

Distribuzione Linux immutabile basata su **Origami Linux** (Fedora Atomic + kernel **CachyOS**), con compositor **Niri** e shell **DankMaterialShell (DMS)** forzati su tutte le varianti.

## Varianti

| Variante | Base | Uso | Stato |
|---|---|---|---|
| `desktop` | Origami Linux | Workstation minimalista + sviluppo | ✅ Disponibile |
| `puregaming` | `atomik-desktop` | Gaming puro su base desktop | ✅ Disponibile |
| `desktop-nvidia` | RAKU-OS + driver NVIDIA | Workstation con GPU NVIDIA | ✅ Disponibile - BETA |
| `puregaming-nvidia` | `desktop-nvidia` + driver NVIDIA | Gaming con GPU NVIDIA |  ✅ Disponibile - BETA |
| `handheld` | `atomik-desktop` | Steam Deck per power users | ✅ Disponibile |

`puregaming` eredita interamente da `desktop`: tutto ciò che è nella base (Niri, DMS, greetd, ujust, Brave, Bazaar) è presente anche in gaming.

## Installazione

### Da ISO (consigliato)

Le ISO vengono generate dal workflow **Build Atomik OS ISO** (Actions → Run workflow → scegli la variante) e pubblicate su storage S3.

Il flusso di installazione:

1. Avvii l'installer (Anaconda) e completi l'installazione interattiva: lingua, **tastiera**, disco, utente.
2. Al **primo boot** il sistema passa automaticamente all'immagine Atomik della variante scelta e riavvia.
3. Al **secondo boot** sei su Atomik OS. Le app Flatpak vengono scaricate in background (vedi *Primo avvio*).

### Da rebase

Per passare ad Atomik OS da un sistema Fedora Atomic / bootc esistente:

```bash
# Variante desktop
sudo bootc switch ghcr.io/giurest/atomik-desktop:latest

# Variante gaming
sudo bootc switch ghcr.io/giurest/atomik-puregaming:latest
```

Poi `sudo reboot`.

## Primo avvio

Al primo boot un servizio installa automaticamente le app Flatpak da Flathub (richiede connessione di rete e qualche minuto). Non serve lanciare comandi manualmente.

> **Importante**: le app Flatpak vengono installate *mentre la sessione è già attiva*, quindi il launcher di DMS potrebbe non mostrarle subito. Una volta completato il download, esegui un **restart di DMS** per farle comparire:
>
> ```bash
> dms restart
> ```
>
> (oppure usa la voce "Riavvia DMS" dal menu di DMS). È necessario una sola volta, al primissimo avvio di un sistema nuovo.

## Comandi di sistema (ujust)

Atomik include `ujust`, un set di comandi per le operazioni comuni. Esegui `ujust` senza argomenti per la lista completa. Tra le ricette disponibili:

```bash
ujust create-user      # crea un nuovo utente
ujust update           # aggiorna il sistema (bootc upgrade)
ujust status           # stato dell'immagine bootc
ujust rollback         # torna all'immagine precedente
ujust set-wallpaper    # imposta lo sfondo Atomik
```

## Software incluso

### Base (Desktop — presente su tutte le varianti)

- **Compositor**: Niri (sessione di default)
- **Shell desktop**: DankMaterialShell (DMS) + dms-greeter
- **Login**: greetd con dms-greeter
- **Terminale**: Alacritty + Fish + Starship
- **File manager**: Nautilus
- **Tema**: Papirus icons
- **Boot**: Plymouth con tema Atomik
- **Browser**: Brave (Flatpak)
- **Store app**: Bazaar (Flatpak) — per installare facilmente altre applicazioni
- **Utility Flatpak**: Flatseal, Telegram
- **CLI**: eza, bat, ripgrep, fd, htop, fastfetch
- **Container**: podman, distrobox

### PureGaming (in aggiunta alla base)

- **Tool di sistema**: MangoHud, GameMode (via RPMFusion)
- **Client di gioco** (Flatpak): Steam, Lutris, Heroic
- **Comunicazione** (Flatpak): Discord, TeamSpeak3
- **Ottimizzazioni**: sysctl gaming (swappiness, max_map_count)

## Installare altre app

Usa **Bazaar** (lo store grafico) per installare qualsiasi altra applicazione Flatpak da Flathub, senza modificare l'immagine. In alternativa, da terminale:

```bash
flatpak install flathub <app-id>
```

## Struttura repo

```
atomik-os/
├── .github/workflows/
│   ├── build.yml          # Build immagini OCI → ghcr.io (desktop + derivate)
│   └── iso-manual.yml     # Genera ISO per variante (workflow_dispatch)
├── containerfiles/
│   ├── Containerfile.desktop      # base (FROM Origami)
│   └── Containerfile.puregaming   # FROM atomik-desktop
├── installer/
│   ├── atomik-desktop.toml        # kickstart ISO desktop
│   └── atomik-puregaming.toml     # kickstart ISO puregaming
├── files/
│   ├── niri/              # config Niri di sistema
│   ├── plymouth/atomik/   # tema Plymouth
│   ├── fastfetch/         # config fastfetch per variante
│   ├── ujust/             # justfile con i comandi di sistema
│   ├── skel/              # skel utenti (autostart wallpaper)
│   └── system/            # file copiati nel sistema (script flatpak, ujust wrapper, ...)
└── packages/              # liste pacchetti per variante
```

## Personalizzare i pacchetti

Modifica i file in `packages/` — un pacchetto per riga, commenti con `#`. Ogni variante legge la propria lista. I client di gioco e le app desktop sono invece gestiti come Flatpak negli script in `files/system/usr/bin/atomik-flatpak-*`.

## Build locale (opzionale)

```bash
# Richiede podman o buildah
buildah build -f containerfiles/Containerfile.desktop -t atomik-desktop:local .
```

> Nota: `Containerfile.puregaming` parte da `ghcr.io/giurest/atomik-desktop:latest`, quindi per buildarlo localmente serve prima l'immagine desktop.

## Note tecniche

- Il sistema è **bootc/OSTree**: aggiornamenti atomici con `bootc upgrade`, rollback con `bootc rollback`.
- **Non rimuovere `podman`**: su bootc trascina via `bootc` e `rpm-ostree`, rendendo il sistema non aggiornabile.
- `ID` in `/etc/os-release` resta `fedora` (richiesto da bootc-image-builder per la ISO); il branding Atomik è in `NAME`/`PRETTY_NAME`.

---

> **Requisiti**: CPU x86-64-v3 o superiore (verifica con `/lib64/ld-linux-x86-64.so.2 --help | grep supported`).
