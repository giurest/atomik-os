# Atomik OS — Variante Hypervisor

Guida al modello **VM-as-a-service** della variante hypervisor di Atomik OS.

## Panoramica

La variante hypervisor estende `atomik-desktop` con lo stack completo di virtualizzazione (libvirt, QEMU/KVM). Il suo scopo è ospitare servizi come macchine virtuali isolate, secondo il principio **una VM = un servizio**.

Ogni servizio (media server, database, web server...) vive nella propria VM, basata sull'immagine immutabile `atomik-server`. I servizi non vengono "installati" nella VM — girano come **container Podman** (quadlet) sopra la base immutabile. Questo garantisce isolamento, riproducibilità e la possibilità di ricreare qualsiasi servizio da zero con un singolo comando.

### Principi

- **L'utente pensa in nomi, non in IP** — gli indirizzi sono assegnati e gestiti automaticamente.
- **Tutto permanente** — IP, reservation e autostart sopravvivono ai riavvii. 
- **Lo stato vive in libvirt** — la configurazione delle VM è nella network XML di libvirt, unica fonte di verità.
- **Isolamento per VM** — un servizio compromesso non ha accesso ai dati degli altri: non li monta nemmeno.

## Architettura

### Rete

Le VM sono connesse alla rete NAT `default` di libvirt (`virbr0`, `192.168.122.0/24`). Ogni VM riceve un **IP permanente** tramite una DHCP reservation (MAC → IP) scritta  nella network XML.

La **reservation nella network XML è l'unica fonte di verità** per gli IP. I lease dinamici di dnsmasq non vengono considerati per l'allocazione, perché possono contenere residui di VM cancellate (vedi *Note tecniche*).

### Servizi libvirt

L'hypervisor usa i **socket modulari** di libvirt (`virtqemud`, `virtnetworkd`,  `virtstoraged`) invece del monolitico `libvirtd`. Si attivano on-demand, sono più leggeri e robusti.

L'accesso a libvirt è concesso al gruppo `wheel` tramite regola polkit — nessun username cablato nell'immagine.

## Ciclo di vita di una VM

### Creare una VM base — `atomik-server`
`ujust atomik-server`
Chiede nome, username, RAM, vCPU e se avviare la VM automaticamente al boot 
dell'hypervisor. **Non chiede l'IP**: viene assegnato automaticamente.

Cosa fa:
1. Aggiorna l'immagine base se ne esiste una più recente (vedi `vm-base-update`)
2. Alloca la prima coppia IP+MAC libera e scrive la reservation permanente
3. Crea la VM con il MAC riservato, così al boot riceve esattamente quell'IP
4. Imposta l'autostart (se richiesto)

Al termine stampa l'IP permanente e il comando SSH per accedere.

### Accesso e primo login

Le VM `atomik-server` hanno il servizio **SSH attivo di default**, ma raggiungibile **solo dall'hypervisor** (rete NAT interna). Non è esposto alla LAN: per renderlo accessibile dall'esterno va esposto esplicitamente con `vm-forward` (vedi oltre).

Al primo accesso lo username è quello scelto in fase di creazione e la
**password coincide con lo username**. Al primo login il sistema **obbliga a
cambiarla** prima di procedere.

ssh <utente>@<ip-vm> # dall'hypervisor


> Dopo aver messo in sicurezza il login della VM (cambio password, ed 
> eventuale hardening), si possono lanciare le ricette di configurazione.

### Inventario — `vm-list`
Elenca le VM con nome, IP (risolto dalla reservation), stato e autostart.
Aggiungi `verbose` per i dettagli sulla risoluzione.

### Esporre un servizio sulla LAN — `vm-forward`

Le VM sono su una rete interna (NAT), non raggiungibili direttamente dalla LAN.
Per esporre la porta di un servizio si crea un forward:
`ujust vm-forward <nome-vm> <porta-vm> [porta-host opzionale se omessa viene usata la porta vm indicata]`

Il forward è un servizio systemd con `socat`, persistente al riavvio. Se la porta host è già occupata, la ricetta suggerisce la prima libera.

Ricette correlate:
- `ujust vm-forward-list` — elenca i forward attivi
- `ujust vm-forward-remove <nome-vm> <porta-host>` — rimuove un forward

### Rimuovere una VM — `vm-delete`

`ujust vm-delete`

Chiede il **nome** della VM (non l'Id numerico) e, dopo conferma, rimuove in
un colpo solo:
- la VM e tutti i suoi dischi
- il seed cloud-init
- la DHCP reservation (libera l'IP)
- **tutti i port forward** associati alla VM (servizio + porta firewall)

L'anteprima mostra reservation e forward che verranno rimossi prima della
conferma.

### Aggiornare l'immagine base — `vm-base-update`

`ujust vm-base-update [force]`

Controlla (tramite ETag) se su GitHub esiste una versione più recente della qcow2 base e la scarica solo se cambiata. Viene invocata automaticamente da `atomik-server`, quindi ogni VM nuova nasce già aggiornata. Usa `force` per forzare il riscaricamento. questa ricetta è inclusa in `ujust atomik-server`

## Servizi specialistici

Un servizio si installa **dentro la VM**, dopo averla creata. Ogni ricetta `*-setup` trasforma una VM base generica nel servizio specifico: monta lo storage necessario, scrive il quadlet Podman e avvia il container. 
Tutte le ricette `*-setup` chiedono all'inizio l'**hostname** da assegnare alla VM (identifica la macchina nella rete e nel prompt).

### Jellyfin — `jellyfin-setup`

Media server. Monta uno share SMB dal NAS come storage dei media e avvia il
container Jellyfin.

> Lanciare all'interno della vm `ujust jellyfin-setup`

Chiede i parametri del mount SMB (share, utente, password). Il container espone
la porta **8096** dentro la VM. Per generare più istanze del servizio conviene creare più vm e tramite forward assegnare porte diverse.

### Database MariaDB — `db-setup`

Database server riutilizzabile da più applicazioni.

> Lanciare all'interno della vm `ujust db-setup`

Chiede la password root, e nome/utente/password del primo database. Le credenziali sono salvate in `/etc/atomik-db/mariadb.env` (permessi `0600`, solo nella VM). I dati risiedono su disco locale (`/var/lib/mariadb`), **mai su SMB** — MariaDB non è affidabile su CIFS. Il container espone la porta **3306**.

> L'IP della VM database va annotato: servirà al web server per connettersi.

### Web server — `webserver-setup`

Apache + PHP 8.4 + phpMyAdmin, per app Laravel, CodeIgniter, WordPress o PHP
standard.

> Lanciare all'interno della vm `ujust db-setup`

Chiede l'IP del database server e le porte (default 8080 web, 8081 phpMyAdmin). Il codice dell'app va caricato via **SFTP** in `/var/lib/webserver/www`, con DocumentRoot fisso su `public/` (convenzione per Laravel/CI4; per WordPress e PHP standard, mettere i file dentro `public/`). 

Le dipendenze si installano con Composer dentro il container:
sudo podman exec -it systemd-webserver composer install

> Dopo il setup, riconnettiti via SSH: l'utente viene aggiunto al gruppo del
> web server (necessario per caricare i file via SFTP).

## Guida rapida — stack LAMP (WordPress)

Esempio completo: WordPress con web e database su due VM separate.

**1. VM database** (sull'hypervisor)
ujust atomik-server # nome: db, autostart sì

Accedi e configura:

ssh <username>@<ip-db>
ujust db-setup # annota l'IP della VM

**2. VM web** (sull'hypervisor)

ujust atomik-server # nome: web, autostart sì

Accedi e configura:

ssh <username>@<ip-web>
ujust webserver-setup # indicare l'ip del database quando richiesto: <ip-db>

**3. Esponi sulla LAN** (sull'hypervisor)
ujust vm-forward <nome-vm> 80 8080 # sito
ujust vm-forward <nome-vm> 81 8081 # phpMyAdmin

**4. Carica WordPress** via SFTP in `/var/lib/webserver/www/public`, poi apri
`http://<ip-hypervisor>:8080` e completa l'installazione guidata (host DB =
IP della VM database).

## Note tecniche e caveat

### Lease DHCP residui dopo `vm-delete`

`vm-delete` rimuove la reservation dalla network XML, ma il lease DHCP resta
nella cache di dnsmasq (`/var/lib/libvirt/dnsmasq/virbr0.status`) fino alla
scadenza (~1h). Se si ricrea una VM subito dopo, l'IP liberato può risultare
ancora occupato e la nuova VM riceve un indirizzo dal pool invece della sua
reservation.

**Sintomo**: la VM ha un IP diverso da quello mostrato in `vm-list`.

**Rimedio**: attendere la scadenza del lease, oppure forzare la pulizia:
sudo virsh net-destroy default
sudo mv /var/lib/libvirt/dnsmasq/virbr0.status /tmp/
sudo virsh net-start default

Il restart della rete lascia il bridge in `NO-CARRIER`: le VM vanno riavviate
con `virsh destroy <vm>` + `virsh start <vm>` (non `reboot`, che non ricrea le
interfacce lato host).

### `/mnt` non canonico su bootc

Su bootc `/mnt` è un symlink verso `/var/mnt`. systemd rifiuta i mount su path
non canonici, quindi le ricette risolvono sempre il path reale con
`readlink -f` prima di creare le unit `.mount`.

### Permessi web server (www-data)

Apache nel container serve le pagine come `www-data` (UID 33). Perché possa
scrivere (config, upload, cache dei framework), `webserver-setup` assegna la
cartella del progetto all'UID/GID 33 e aggiunge l'utente a quel gruppo per
l'accesso SFTP. Con Podman rootful, l'UID 33 del container coincide con quello
dell'host.

### socat invece del port-forwarding di firewalld

L'esposizione LAN usa servizi `socat` hardened (`DynamicUser`, `ProtectSystem`,
`NoNewPrivileges`) invece del forwarding di zona di firewalld, risultato più
affidabile nei test.

### Hostname per-VM

L'immagine base forza l'hostname `atomik-server` tramite un `tmpfiles.d` che
ricrea il symlink `/etc/hostname` a ogni boot. Le ricette `*-setup` lo
neutralizzano (symlink a `/dev/null` in `/etc/tmpfiles.d/`) e impostano
l'hostname scelto, reso così persistente.

Il nuovo hostname è attivo subito a livello di sistema, ma la **sessione SSH in
corso mantiene il prompt vecchio** fino al prossimo logout/login. Anche la
registrazione del nome nei lease DHCP avviene al rinnovo del lease.

Tutte le ricette `*-setup` chiedono all'inizio l'**hostname** da assegnare alla
VM. Il cambio ha effetto immediato sul sistema, ma il **prompt della sessione
SSH corrente continua a mostrare il vecchio nome**: si aggiorna solo dopo
logout/login.

## Sicurezza

- **Default deny sul firewall** — l'hypervisor espone alla LAN solo le
  porte che l'utente apre esplicitamente via `vm-forward`.
- **Credenziali in file dedicati** — password SMB e database in file a `0600`,
  mai nei quadlet o nelle unit systemd.
- **Isolamento per VM** — ogni servizio nella propria VM; un database non è mai
  esposto sulla LAN (solo le VM interne lo raggiungono via NAT).