# Atomik OS

Distribuzione Linux immutabile basata su **Fedora Atomic** con kernel **CachyOS**, compositor **Niri** e tema **Noctalia** forzati su tutte le varianti.

## Varianti

| Variante | Base | Uso |
|---|---|---|
| `desktop` | Origami Linux | Workstation minimalista + sviluppo |
| `desktop-nvidia` | desktop + driver NVIDIA | Workstation con GPU NVIDIA |
| `puregaming` | Origami Linux | Gaming puro, zero bloat |
| `puregaming-nvidia` | puregaming + driver NVIDIA | Gaming con GPU NVIDIA |
| `handheld` | Bazzite Deck | Steam Deck e dispositivi portatili |

## Rebase

Per passare ad Atomik OS da qualsiasi sistema Fedora Atomic:

```bash
# Variante desktop
sudo bootc switch ghcr.io/giurest/atomik-desktop:latest

# Variante gaming
sudo bootc switch ghcr.io/giurest/atomik-puregaming:latest

# Variante handheld
sudo bootc switch ghcr.io/giurest/atomik-handheld:latest
```

## Primo boot

Dopo il reboot, installa le app Flatpak:

```bash
bash /usr/share/atomik/scripts/setup-flatpaks.sh desktop
# oppure: puregaming | handheld
```

## Software incluso (Desktop)

- **Shell**: Ghostty + Fish + Starship
- **Compositor**: Niri (forzato, non rimuovibile)
- **Tema**: Noctalia + Papirus icons + Bibata cursors
- **Browser**: Brave debloated con sync attivo
- **Sviluppo**: VSCodium, GitFiend, OnlyOffice (via Flatpak)
- **Login**: SDDM con tema Atomik custom
- **Boot**: Plymouth con tema Atomik custom

## Struttura repo

```
atomik-os/
├── .github/workflows/
│   ├── build.yml          # Build immagini OCI → ghcr.io
│   └── build-disk.yml     # Genera ISO
├── containerfiles/        # Un Containerfile per variante
├── files/
│   ├── plymouth/          # Tema Plymouth (da personalizzare)
│   ├── sddm/              # Tema SDDM (da personalizzare)
│   └── system/            # File copiati nel sistema
├── packages/              # Liste pacchetti per variante
└── scripts/               # Script post-installazione
```

## Personalizzare i pacchetti

Modifica i file in `packages/` — un pacchetto per riga, commenti con `#`. Il build legge automaticamente la lista corretta per ogni variante.

## Build locale (opzionale)

```bash
# Richiede podman o buildah
buildah build -f containerfiles/Containerfile.desktop -t atomik-desktop:local .
```

## Assets grafici

I temi Plymouth e SDDM in `files/plymouth/` e `files/sddm/` sono placeholder. Sostituisci con i tuoi assets grafici mantenendo la struttura dei file.

---

> **Nota**: richiede CPU x86-64-v3 o superiore (verifica con `/lib64/ld-linux-x86-64.so.2 --help | grep supported`).
