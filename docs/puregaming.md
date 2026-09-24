# Atomik OS — Variante PureGaming

> 🚧 Documentazione in elaborazione

La variante **puregaming** estende `atomik-desktop` con ottimizzazioni per il gaming. Tutto ciò che è presente nel desktop è disponibile anche qui.

## Caratteristiche aggiuntive rispetto al desktop

- **GPU overlay**: MangoHud (per-gioco via Steam launch options, non globale)
- **Performance**: GameMode, sysctl gaming (swappiness=10, max_map_count=2147483642)
- **Client di gioco**: Steam, Lutris (RPM); Heroic (Flatpak)
- **Comunicazione**: Discord, TeamSpeak3 (Flatpak)

## Varianti NVIDIA

La variante `puregaming-nvidia` include i driver NVIDIA proprietari. Per le GPU AMD/Intel usa `puregaming`.

## Installazione

```bash
curl -fsSL https://giurestlabs.it/get-atomik | bash
# → scegli "puregaming" o "puregaming-nvidia"
```

## Note su MangoHud

MangoHud è disponibile ma **non attivo globalmente** — viene iniettato solo sui giochi Steam via `mangohud-vdf.py`. L'attivazione globale è disponibile ma sconsigliata su NVIDIA (rischio crash KWin).

```bash
ujust mangohud-enable  # attiva globalmente (con avviso)
```

---

*Per la guida completa all'installazione, vedi il [README principale](../README.md).*
