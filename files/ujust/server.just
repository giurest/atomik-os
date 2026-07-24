# ═══════════════════════════════════════════════════════════════════════════════
#  Atomik OS Server — ujust
#  Host minimale per container (base fedora-bootc).
# ═══════════════════════════════════════════════════════════════════════════════

import? 'common.just'

# [Servizi] Configura Jellyfin in questa VM (mount SMB + quadlet Podman)
jellyfin-setup:
    #!/usr/bin/env bash
    set -euo pipefail

    QUADLET="/etc/containers/systemd/jellyfin.container"
    MOUNT_PATH="/var/mnt/storage"

    echo "┌────────────────────────────────────────────────┐"
    echo "  Jellyfin — setup servizio in questa VM          "
    echo "└────────────────────────────────────────────────┘"
    echo ""
    echo "  Questa ricetta:"
    echo "   1. monta lo storage SMB dal NAS (→ ${MOUNT_PATH})"
    echo "   2. crea il quadlet Podman di Jellyfin"
    echo "   3. avvia il servizio"
    echo ""

    # ── Verifica che Jellyfin non sia già configurato ────────────────────────
    if [[ -f "$QUADLET" ]]; then
        echo "✗ Jellyfin risulta già configurato ($QUADLET)."
        echo "  Rimuovilo prima di rieseguire il setup."
        exit 1
    fi

    # ── 1. Mount dello storage SMB (nome fisso 'storage') ────────────────────
    # Se già montato (da un setup precedente), saltiamo; altrimenti invochiamo
    # smb-system con il nome 'storage' (il resto è interattivo).
    if mountpoint -q "$MOUNT_PATH" 2>/dev/null; then
        echo "✓ Storage già montato in ${MOUNT_PATH}, salto smb-system."
    else
        echo "→ Configuro il mount SMB dello storage..."
        echo "  (rispondi alle domande su share NAS, utente e password)"
        echo ""
        ujust smb-system storage
        # Verifica che il mount sia effettivamente attivo prima di procedere
        if ! mountpoint -q "$MOUNT_PATH" 2>/dev/null; then
            echo "✗ Lo storage non risulta montato in ${MOUNT_PATH}."
            echo "  Setup interrotto: Jellyfin ha bisogno dello storage."
            exit 1
        fi
    fi

    # ── 2. Scrivi il quadlet Jellyfin (fisso) ────────────────────────────────
    echo "→ Creo il quadlet Podman di Jellyfin..."
    sudo mkdir -p /var/lib/jellyfin/config /var/lib/jellyfin/cache

    printf '%s\n' \
        "[Unit]" \
        "Description=Jellyfin Media Server" \
        "After=network-online.target var-mnt-storage.mount" \
        "Wants=network-online.target" \
        "" \
        "[Container]" \
        "Image=docker.io/jellyfin/jellyfin:latest" \
        "PublishPort=8096:8096" \
        "Volume=/var/lib/jellyfin/config:/config:Z" \
        "Volume=/var/lib/jellyfin/cache:/cache:Z" \
        "Volume=/var/mnt/storage:/media" \
        "" \
        "[Service]" \
        "Restart=always" \
        "TimeoutStartSec=900" \
        "" \
        "[Install]" \
        "WantedBy=multi-user.target" \
        | sudo tee "$QUADLET" > /dev/null

    # ── 3. Avvia il servizio ─────────────────────────────────────────────────
    echo "→ Avvio Jellyfin..."
    sudo systemctl daemon-reload
    sudo systemctl start jellyfin.service

    echo ""
    echo "✓ Jellyfin configurato e avviato."
    echo "  Interno VM:  http://$(hostname -I | awk '{print $1}'):8096"
    echo ""
    echo "  Per esporlo sulla LAN, dall'HYPERVISOR:"
    echo "    ujust vm-forward $(hostname) 8096 <porta-host>"
    echo ""
    echo "  Al primo avvio Jellyfin scarica l'immagine: attendi ~1 min,"
    echo "  poi completa la configurazione guidata dal browser."

# [Servizi] Configura MariaDB in questa VM (database server)
db-setup:
    #!/usr/bin/env bash
    set -euo pipefail

    QUADLET="/etc/containers/systemd/mariadb.container"
    ENV_DIR="/etc/atomik-db"
    ENV_FILE="${ENV_DIR}/mariadb.env"
    DATA_DIR="/var/lib/mariadb"

    echo "┌────────────────────────────────────────────────┐"
    echo "  MariaDB — setup database server in questa VM   "
    echo "└────────────────────────────────────────────────┘"
    echo ""
    echo "  Questa ricetta:"
    echo "   1. raccoglie le credenziali (root + primo database)"
    echo "   2. le salva in ${ENV_FILE} (0600, solo in questa VM)"
    echo "   3. crea il quadlet Podman di MariaDB"
    echo "   4. avvia il servizio"
    echo ""
    echo "  I dati risiedono su disco locale (${DATA_DIR}):"
    echo ""

    # ── Verifica che non sia già configurato ─────────────────────────────────
    if [[ -f "$QUADLET" ]]; then
        echo "✗ MariaDB risulta già configurato ($QUADLET)."
        echo "  Credenziali attuali: sudo cat ${ENV_FILE}"
        echo "  Per rifare il setup rimuovi prima il quadlet."
        exit 1
    fi

    # ── 1. Credenziali ───────────────────────────────────────────────────────
    read -srp "Password ROOT del database: " DB_ROOT_PASS
    echo ""
    read -srp "Conferma password ROOT: " DB_ROOT_PASS2
    echo ""
    [[ "$DB_ROOT_PASS" != "$DB_ROOT_PASS2" ]] && { echo "✗ Le password non coincidono."; exit 1; }
    [[ -z "$DB_ROOT_PASS" ]] && { echo "✗ Password root vuota."; exit 1; }

    echo ""
    read -rp "Nome del primo database (es. laravel_app): " DB_NAME
    [[ -z "$DB_NAME" ]] && { echo "✗ Nome database vuoto."; exit 1; }

    read -rp "Utente applicativo (es. app_user): " DB_USER
    [[ -z "$DB_USER" ]] && { echo "✗ Utente vuoto."; exit 1; }

    read -srp "Password utente applicativo: " DB_PASS
    echo ""
    read -srp "Conferma password utente: " DB_PASS2
    echo ""
    [[ "$DB_PASS" != "$DB_PASS2" ]] && { echo "✗ Le password non coincidono."; exit 1; }
    [[ -z "$DB_PASS" ]] && { echo "✗ Password utente vuota."; exit 1; }

    VM_IP="$(hostname -I | awk '{print $1}')"

    echo ""
    echo "→ Configurazione:"
    echo "  Database:  ${DB_NAME}"
    echo "  Utente:    ${DB_USER}"
    echo "  Dati:      ${DATA_DIR}"
    echo "  Env file:  ${ENV_FILE} (0600)"
    echo "  Ascolto:   ${VM_IP}:3306"
    echo ""
    read -rp "Confermi? [s/N]: " CONFIRM
    [[ ! "$CONFIRM" =~ ^[sS]$ ]] && { echo "Operazione annullata."; exit 0; }

    cleanup_on_error() {
        echo ""
        echo "✗ Errore durante la creazione: rimuovo i file parziali."
        sudo rm -f "$QUADLET" "$ENV_FILE"
        sudo systemctl daemon-reload || true
    }
    trap cleanup_on_error ERR

    # ── 2. File env con le credenziali (0600, solo in questa VM) ─────────────
    sudo mkdir -p "$ENV_DIR"
    sudo chmod 700 "$ENV_DIR"
    printf '%s\n' \
        "MARIADB_ROOT_PASSWORD=${DB_ROOT_PASS}" \
        "MARIADB_DATABASE=${DB_NAME}" \
        "MARIADB_USER=${DB_USER}" \
        "MARIADB_PASSWORD=${DB_PASS}" \
        | sudo tee "$ENV_FILE" > /dev/null
    sudo chmod 600 "$ENV_FILE"

    # ── 3. Quadlet MariaDB ───────────────────────────────────────────────────
    echo "→ Creo il quadlet Podman di MariaDB..."
    sudo mkdir -p "$DATA_DIR"

    printf '%s\n' \
        "[Unit]" \
        "Description=MariaDB Database Server" \
        "After=network-online.target" \
        "Wants=network-online.target" \
        "" \
        "[Container]" \
        "Image=docker.io/mariadb:11" \
        "PublishPort=3306:3306" \
        "Volume=${DATA_DIR}:/var/lib/mysql:Z" \
        "EnvironmentFile=${ENV_FILE}" \
        "" \
        "[Service]" \
        "Restart=always" \
        "TimeoutStartSec=300" \
        "" \
        "[Install]" \
        "WantedBy=multi-user.target" \
        | sudo tee "$QUADLET" > /dev/null

    # ── 4. Avvio ─────────────────────────────────────────────────────────────
    echo "→ Avvio MariaDB..."
    sudo systemctl daemon-reload
    sudo systemctl start mariadb.service
    trap - ERR

    echo ""
    echo "✓ MariaDB configurato e avviato."
    echo ""
    echo "  Indirizzo per le app:  ${VM_IP}:3306"
    echo "  Database:              ${DB_NAME}"
    echo "  Utente:                ${DB_USER}"
    echo ""
    echo "  Credenziali salvate in: ${ENV_FILE}"
    echo "  Per consultarle:        sudo cat ${ENV_FILE}"
    echo ""
    echo "  Annota l'IP ${VM_IP}: servirà alle altre VM per consentire le connessioni ."
    echo ""
    echo "  Al primo avvio MariaDB inizializza il database: attendere circa ~30s."

# [Servizi] Configura Apache+PHP e phpMyAdmin in questa VM
webserver-setup:
    #!/usr/bin/env bash
    set -euo pipefail

    QUADLET_WEB="/etc/containers/systemd/webserver.container"
    QUADLET_PMA="/etc/containers/systemd/phpmyadmin.container"
    NET_QUADLET="/etc/containers/systemd/webserver.network"
    WWW_DIR="/var/lib/webserver/www"

    echo "┌────────────────────────────────────────────────┐"
    echo "  Atomik Webserver — Apache + PHP + phpMyAdmin           "
    echo "└────────────────────────────────────────────────┘"
    echo ""
    echo "  Questa ricetta:"
    echo "   1. crea la cartella del progetto (${WWW_DIR})"
    echo "   2. crea i quadlet Podman (Apache+PHP, phpMyAdmin)"
    echo "   3. avvia i servizi"
    echo ""
    echo "  Il codice va caricato via SFTP in ${WWW_DIR}"
    echo "  DocumentRoot: ${WWW_DIR}/public (convenzione Atomik)"
    echo ""

    # ── Verifica che non sia già configurato ─────────────────────────────────
    if [[ -f "$QUADLET_WEB" ]]; then
        echo "✗ Webserver risulta già configurato ($QUADLET_WEB)."
        echo "  Rimuovi i quadlet prima di rieseguire il setup."
        exit 1
    fi

    # ── Parametri ────────────────────────────────────────────────────────────
    read -rp "IP del database server (es. 192.168.122.3): " DB_HOST
    [[ -z "$DB_HOST" ]] && { echo "✗ IP database vuoto."; exit 1; }

    read -rp "Porta web (Apache) [8080]: " WEB_PORT
    WEB_PORT="${WEB_PORT:-8080}"

    read -rp "Porta phpMyAdmin [8081]: " PMA_PORT
    PMA_PORT="${PMA_PORT:-8081}"

    VM_IP="$(hostname -I | awk '{print $1}')"

    echo ""
    echo "→ Configurazione:"
    echo "  Progetto:    ${WWW_DIR}"
    echo "  DocumentRoot:${WWW_DIR}/public"
    echo "  Database:    ${DB_HOST}:3306"
    echo "  Web:         ${VM_IP}:${WEB_PORT}"
    echo "  phpMyAdmin:  ${VM_IP}:${PMA_PORT}"
    echo ""
    read -rp "Confermi? [s/N]: " CONFIRM
    [[ ! "$CONFIRM" =~ ^[sS]$ ]] && { echo "Operazione annullata."; exit 0; }

    cleanup_on_error() {
        echo ""
        echo "✗ Errore durante la creazione: rimuovo i file parziali."
        sudo rm -f "$QUADLET_WEB" "$QUADLET_PMA" "$NET_QUADLET"
        sudo systemctl daemon-reload || true
    }
    trap cleanup_on_error ERR

    # ── 1. Cartella progetto (owner utente, per upload SFTP) ─────────────────
    sudo mkdir -p "${WWW_DIR}/public"
    sudo chown -R "$(id -u):$(id -g)" /var/lib/webserver
    sudo chmod -R 775 /var/lib/webserver

    # Pagina di benvenuto se la public e' vuota
    if [[ -z "$(ls -A "${WWW_DIR}/public" 2>/dev/null)" ]]; then
        printf '%s\n' \
            "<!DOCTYPE html><html><head><meta charset=\"utf-8\">" \
            "<title>Atomik Webserver</title></head><body>" \
            "<h1>Atomik Webserver attivo</h1>" \
            "<p>Carica il progetto via SFTP in ${WWW_DIR}</p>" \
            "<p><?php echo 'PHP ' . phpversion(); ?></p>" \
            "</body></html>" \
            > "${WWW_DIR}/public/index.php"
    fi

    # ── 2. Rete interna per i container ──────────────────────────────────────
    printf '%s\n' \
        "[Network]" \
        "NetworkName=webserver" \
        | sudo tee "$NET_QUADLET" > /dev/null

    # ── 3. Quadlet Apache + PHP ──────────────────────────────────────────────
    echo "→ Creo il quadlet Apache+PHP..."
    printf '%s\n' \
        "[Unit]" \
        "Description=Atomik Webserver - Apache + PHP" \
        "After=network-online.target" \
        "Wants=network-online.target" \
        "" \
        "[Container]" \
        "Image=ghcr.io/giurest/atomik-php:latest" \
        "Network=webserver.network" \
        "PublishPort=${WEB_PORT}:80" \
        "Volume=${WWW_DIR}:/var/www/html:Z" \
        "" \
        "[Service]" \
        "Restart=always" \
        "TimeoutStartSec=300" \
        "" \
        "[Install]" \
        "WantedBy=multi-user.target" \
        | sudo tee "$QUADLET_WEB" > /dev/null

    # ── 4. Quadlet phpMyAdmin ────────────────────────────────────────────────
    echo "→ Creo il quadlet phpMyAdmin..."
    printf '%s\n' \
        "[Unit]" \
        "Description=phpMyAdmin" \
        "After=network-online.target" \
        "Wants=network-online.target" \
        "" \
        "[Container]" \
        "Image=docker.io/phpmyadmin:latest" \
        "Network=webserver.network" \
        "PublishPort=${PMA_PORT}:80" \
        "Environment=PMA_HOST=${DB_HOST}" \
        "Environment=PMA_PORT=3306" \
        "Environment=UPLOAD_LIMIT=64M" \
        "" \
        "[Service]" \
        "Restart=always" \
        "TimeoutStartSec=300" \
        "" \
        "[Install]" \
        "WantedBy=multi-user.target" \
        | sudo tee "$QUADLET_PMA" > /dev/null

    # ── 5. Avvio ─────────────────────────────────────────────────────────────
    echo "→ Avvio i servizi..."
    sudo systemctl daemon-reload
    sudo systemctl start webserver.service
    sudo systemctl start phpmyadmin.service
    trap - ERR

    echo ""
    echo "✓ Webserver configurato e avviato."
    echo ""
    echo "  Web:         http://${VM_IP}:${WEB_PORT}"
    echo "  phpMyAdmin:  http://${VM_IP}:${PMA_PORT}"
    echo ""
    echo "  Codice:      carica via SFTP in ${WWW_DIR}"
    echo "  Composer:    sudo podman exec -it systemd-webserver composer install"
    echo ""
    echo "  Per esporli sulla LAN, dall'HYPERVISOR:"
    echo "    ujust vm-forward $(hostname) ${WEB_PORT} <porta-host>"
    echo "    ujust vm-forward $(hostname) ${PMA_PORT} <porta-host>"