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

## VR con SteamVR (Wayland)

Su Wayland la vista **Desktop** di SteamVR, quella che mostra lo schermo del PC dentro il visore, funziona solo se Steam cattura lo schermo via PipeWire. Per questo la variante include il lanciatore **Steam (modalità VR)**, che avvia Steam con l'opzione `-pipewire`. Steam normale resta invariato: il lanciatore è un'aggiunta opzionale.

### Come si usa

1. Avvia **Steam (modalità VR)** dal menu. Se Steam è già aperto senza l'opzione, il lanciatore chiede conferma e lo riavvia: i giochi aperti vengono chiusi.
2. La prima volta Plasma chiede quale schermo condividere. Scegli il monitor e conferma **prima di indossare il visore**: la richiesta compare sul monitor del PC, non nel visore. La scelta viene di norma ricordata.
3. Avvia SteamVR e apri la vista Desktop dalla dashboard.

### Limiti noti

- **Input dei controller**: i click funzionano dentro le finestre ma non su pannello e barre del titolo di Plasma, mentre il mouse fisico funziona ovunque. È un limite noto di SteamVR su Wayland, non dipende da Atomik.
- **Avvio automatico di Steam al login**: parte senza `-pipewire`. Se lo usi per la VR, riavvia Steam dal lanciatore.
- **Cambio di monitor o di scheda video**: il permesso ricordato può non essere più valido e la richiesta di condivisione può ricomparire.
- **Remote Play**: l'opzione `-pipewire` può dare problemi su alcuni sistemi, per questo non è attiva di default.

---

*Per la guida completa all'installazione, vedi il [README principale](../README.md).*
