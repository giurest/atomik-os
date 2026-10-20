# ═══════════════════════════════════════════════════════════════════════════════
#  Atomik OS — ollama.just
#  Ollama + Open WebUI in Podman rootless. Caricato da desktop e puregaming
#  (+ varianti nvidia). Logica in /usr/bin/atomik-ollama.
# ═══════════════════════════════════════════════════════════════════════════════

# [AI] Installa Ollama + interfaccia web (Podman, avvio manuale)
ollama-setup:
    @atomik-ollama setup

# [AI] Avvia Ollama e apre l'interfaccia web
ollama-start:
    @atomik-ollama start --open

# [AI] Ferma Ollama e libera RAM/GPU
ollama-stop:
    @atomik-ollama stop

# [AI] Stato di Ollama e modelli in memoria
ollama-status:
    @atomik-ollama status

# [AI] Scarica un modello (es. ujust ollama-pull llama3.2:3b)
ollama-pull model:
    @atomik-ollama pull {{model}}

# [AI] Elenca i modelli scaricati
ollama-list:
    @atomik-ollama list

# [AI] Mostra/imposta uso GPU integrata AMD (ollama-gpu [on|off])
ollama-gpu mode="":
    @atomik-ollama gpu {{mode}}

# [AI] Rimuove Ollama (chiede se eliminare anche i dati)
ollama-remove:
    @atomik-ollama remove
