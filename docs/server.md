# Atomik OS — Variante Server

> 🚧 Documentazione in elaborazione

La variante **server** è un'immagine minimale headless basata su Fedora bootc, progettata per girare come VM sull'hypervisor Atomik. Non fa parte della catena di ereditarietà desktop — è indipendente.

## Caratteristiche

- **Base**: Fedora bootc (minimale, senza DE)
- **Container**: Podman + quadlet systemd
- **Shell**: Fish + Starship + fastfetch
- **Principio**: una VM = un servizio (container Podman)

## Uso

La variante server non si installa direttamente su hardware fisico. Viene distribuita come immagine **qcow2** e viene usata dall'hypervisor Atomik come base per le VM di servizio.

```bash
# Dall'hypervisor
ujust atomik-server    # crea una nuova VM server
```

## Servizi disponibili

Ogni servizio si configura con una ricetta `ujust` dall'interno della VM:

```bash
ujust jellyfin-setup   # media server Jellyfin
ujust db-setup         # database MariaDB
ujust webserver-setup  # web server Apache + PHP + phpMyAdmin
ujust pods-check       # controlla aggiornamenti container
ujust pods-update      # aggiorna i container
ujust disk-expand      # espande il filesystem dopo vm-expand
```

---

*Per la guida completa alla gestione delle VM, vedi [hypervisor.md](hypervisor.md).*
