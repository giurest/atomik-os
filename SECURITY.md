# Sicurezza / Security

[🇮🇹 Italiano](#italiano) · [🇬🇧 English](#english)

---

## Italiano

### Modello di fiducia dell'installer

`curl -fsSL https://giurestlabs.it/get-atomik | bash` esegue `get-atomik.sh`, servito da `giurestlabs.it`. Lo script:

1. scarica `atomik-install.sh`, la sua firma e il checksum da GitHub;
2. scarica la chiave pubblica da `giurestlabs.it/atomik-os/pubkey.gpg`;
3. accetta la chiave **solo** se la sua fingerprint coincide con quella scritta nello script;
4. verifica che la firma sia stata prodotta da quella chiave;
5. solo allora esegue il wizard.

Fingerprint della chiave di firma:

```
08B4 032A E979 4BFB 8F5A  CD90 BE35 CB1E BF3C AD73
```

La chiave privata non è mai nel repo né nella CI. Il checksum SHA256 rileva solo download corrotti.

### Cosa è e cosa non è verificato

| Elemento | Stato |
|---|---|
| `atomik-install.sh` | Firmato GPG, verificato dal bootstrap contro la fingerprint fissata |
| `get-atomik.sh` | Servito dal sito; non è firmato (è lui a verificare) |
| Immagini OCI (`ghcr.io/giurest/atomik-*`) | Firmate con cosign in CI; il client **non** impone ancora la verifica della firma |
| Software di terze parti incluso | Fedora/RPMFusion, Brave, Flathub, Homebrew (immagine ublue-os/brew), starship |

Se `giurestlabs.it` fosse compromesso, il bootstrap potrebbe essere sostituito: il sito è parte della catena di fiducia.

### Verifica manuale (senza `curl | bash`)

```bash
# Leggi il bootstrap prima di eseguirlo
curl -fsSLo get-atomik.sh https://giurestlabs.it/atomik-os/get-atomik.sh
less get-atomik.sh

# Oppure verifica a mano l'installer, in un keyring temporaneo
export GNUPGHOME=$(mktemp -d)
curl -fsSLO https://www.giurestlabs.it/atomik-os/pubkey.gpg
gpg --import pubkey.gpg
gpg --fingerprint 08B4032AE9794BFB8F5ACD90BE35CB1EBF3CAD73   # deve essere l'unica chiave importata
curl -fsSLO https://raw.githubusercontent.com/giurest/atomik-os/main/install/atomik-install.sh
curl -fsSLO https://raw.githubusercontent.com/giurest/atomik-os/main/install/atomik-install.sh.asc
gpg --verify atomik-install.sh.asc atomik-install.sh           # cerca "Good signature" e la stessa fingerprint
less atomik-install.sh
bash atomik-install.sh
```

### Verifica delle immagini

Le immagini sono firmate in CI con [cosign](https://github.com/sigstore/cosign) (firma *keyless* tramite GitHub OIDC). Puoi verificarle a mano quando vuoi; il sistema non lo impone e non blocca gli aggiornamenti non firmati.

```bash
# cosign è disponibile con: brew install cosign
cosign verify ghcr.io/giurest/atomik-desktop:latest \
  --certificate-identity-regexp 'https://github.com/giurest/atomik-os/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

L'esito corretto riporta che le verifiche cosign sono riuscite e mostra come identità un workflow di `giurest/atomik-os`. Sostituisci `atomik-desktop` con la variante che usi (`atomik-desktop-nvidia`, `atomik-puregaming`, `atomik-puregaming-nvidia`, `atomik-hypervisor`, `atomik-server`).

### Segnalare una vulnerabilità

Usa la scheda **Security → Report a vulnerability** di questo repository GitHub (segnalazione privata). Non aprire una issue pubblica per problemi di sicurezza.

---

## English

### Installer trust model

`curl -fsSL https://giurestlabs.it/get-atomik | bash` runs `get-atomik.sh`, served from `giurestlabs.it`. The script:

1. downloads `atomik-install.sh`, its signature and checksum from GitHub;
2. downloads the public key from `giurestlabs.it/atomik-os/pubkey.gpg`;
3. accepts the key **only** if its fingerprint matches the one hardcoded in the script;
4. checks that the signature was produced by that key;
5. only then runs the wizard.

Signing key fingerprint:

```
08B4 032A E979 4BFB 8F5A  CD90 BE35 CB1E BF3C AD73
```

The private key is never in the repo or in CI. The SHA256 checksum only detects corrupted downloads.

### What is and is not verified

| Item | Status |
|---|---|
| `atomik-install.sh` | GPG-signed, verified by the bootstrap against the pinned fingerprint |
| `get-atomik.sh` | Served from the site; not signed (it is the one doing the verification) |
| OCI images (`ghcr.io/giurest/atomik-*`) | Signed with cosign in CI; the client does **not** yet enforce signature verification |
| Bundled third-party software | Fedora/RPMFusion, Brave, Flathub, Homebrew (ublue-os/brew image), starship |

If `giurestlabs.it` were compromised, the bootstrap could be replaced: the site is part of the trust chain.

### Manual verification (without `curl | bash`)

```bash
# Read the bootstrap before running it
curl -fsSLo get-atomik.sh https://giurestlabs.it/atomik-os/get-atomik.sh
less get-atomik.sh

# Or verify the installer by hand, in a temporary keyring
export GNUPGHOME=$(mktemp -d)
curl -fsSLO https://www.giurestlabs.it/atomik-os/pubkey.gpg
gpg --import pubkey.gpg
gpg --fingerprint 08B4032AE9794BFB8F5ACD90BE35CB1EBF3CAD73   # must be the only key imported
curl -fsSLO https://raw.githubusercontent.com/giurest/atomik-os/main/install/atomik-install.sh
curl -fsSLO https://raw.githubusercontent.com/giurest/atomik-os/main/install/atomik-install.sh.asc
gpg --verify atomik-install.sh.asc atomik-install.sh           # look for "Good signature" and the same fingerprint
less atomik-install.sh
bash atomik-install.sh
```

### Image verification

Images are signed in CI with [cosign](https://github.com/sigstore/cosign) (*keyless* signing via GitHub OIDC). You can verify them by hand whenever you like; the system does not enforce this and does not block unsigned updates.

```bash
# cosign is available with: brew install cosign
cosign verify ghcr.io/giurest/atomik-desktop:latest \
  --certificate-identity-regexp 'https://github.com/giurest/atomik-os/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

A successful result reports that the cosign checks passed and shows a `giurest/atomik-os` workflow as the identity. Replace `atomik-desktop` with the variant you use (`atomik-desktop-nvidia`, `atomik-puregaming`, `atomik-puregaming-nvidia`, `atomik-hypervisor`, `atomik-server`).

### Reporting a vulnerability

Use the **Security → Report a vulnerability** tab of this GitHub repository (private report). Please do not open a public issue for security problems.
