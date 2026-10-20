# Ollama + Open WebUI su Atomik OS / Ollama + Open WebUI on Atomik OS

Disponibile su **desktop** e **puregaming** (anche varianti NVIDIA).
Available on **desktop** and **puregaming** (NVIDIA variants included).

## Cosa installa / What it installs

Due container Podman *rootless* (nel tuo utente, nessun privilegio di root), gestiti da unità Quadlet:

| Componente | Immagine (versione fissata) | Porta |
|---|---|---|
| Ollama | `docker.io/ollama/ollama:0.40.6` | `127.0.0.1:11434` |
| Open WebUI | `ghcr.io/open-webui/open-webui:v0.12.3` | `127.0.0.1:3000` |

- **Avvio solo manuale**: nulla parte al boot.
- Le porte sono legate a `127.0.0.1`: non raggiungibili dalla rete locale.
- Ollama gira con `OLLAMA_NO_CLOUD=1` (funzioni cloud disattivate).
- Open WebUI: telemetria (`ANONYMIZED_TELEMETRY`, `SCARF_NO_ANALYTICS`, `DO_NOT_TRACK`) e controllo aggiornamenti (`ENABLE_VERSION_UPDATE_CHECK`) disattivati.

## Comandi / Commands

```bash
ujust ollama-setup          # installa (chiede conferma, controlla 15 GB liberi)
ujust ollama-start          # avvia e apre http://127.0.0.1:3000
ujust ollama-stop           # ferma e libera RAM/GPU
ujust ollama-pull llama3.2:3b   # scarica un modello
ujust ollama-list           # modelli scaricati
ujust ollama-status         # stato servizi e modelli in memoria
ujust ollama-gpu [on|off]   # mostra/imposta uso GPU integrata AMD
ujust ollama-remove         # rimuove (chiede se cancellare anche i dati)
```

Dopo `ollama-setup` compaiono nel menu applicazioni **«Ollama avvio»** e **«Ollama stop»**.

## Spazio e risorse / Space and resources

~14 GB totali (immagini ~10 GB + un modello da ~2 GB + dati Open WebUI).
RAM a riposo, da avviato: ~590 MB (Ollama) + ~1 GB (Open WebUI), più il modello quando in uso.

## GPU

- **CPU**: sempre funzionante.
- **AMD (GPU integrata)**: Ollama ignora le iGPU di default; `ollama-setup` chiede se abilitarla (`OLLAMA_IGPU_ENABLE=1`). Su Radeon 780M, llama3.2:3b Q4_K_M, abbiamo misurato ~25 t/s su CPU contro ~36 t/s su iGPU (singole misure, un solo hardware). Funzione sperimentale di Ollama. Con SELinux in modalità Enforcing bastano `/dev/dri` e `--group-add keep-groups`.
- **NVIDIA**: l'accelerazione in Podman **non è ancora supportata** da questa ricetta (in test); Ollama funziona su CPU.

## Trasparenza sulla rete / Network transparency

- Al **primo avvio** Open WebUI scarica da `huggingface.co` un modello di embedding (all-MiniLM-L6-v2, ~90 MB) usato per la ricerca nei documenti; nessuna variabile di telemetria impedisce questo download.
- I modelli vengono scaricati dal registro di Ollama quando li richiedi.
- Abbiamo verificato solo le richieste HTTP registrate nei log di Open WebUI; non è un'analisi completa del traffico di rete.

## Dati / Data

Volumi Podman `ollama-data` (modelli) e `open-webui-data` (account e chat, in locale).
Il primo account creato in Open WebUI diventa amministratore.
