# Tema SDDM — Atomik OS

## File necessari in questa cartella

```
files/sddm/
├── metadata.desktop         ← descrittore tema (già creato)
├── Main.qml                 ← UI del login in QML
├── background.jpg           ← sfondo (1920x1080)
└── assets/
    ├── logo.png             ← logo Atomik OS
    └── icons/               ← icone utente (opzionale)
```

## metadata.desktop (da creare)

```ini
[SddmGreeterTheme]
Name=Atomik
Description=Atomik OS login theme
Author=giurest
Version=1.0
License=MIT
Type=sddm-theme
```

## Main.qml minimalista (da creare)

Il file QML definisce l'interfaccia grafica della schermata di login.
Puoi partire da un tema esistente come `sugar-candy` e personalizzarlo.

Riferimento: https://github.com/Kangie/sddm-sugar-candy

## Nota

Per ora il Containerfile installa SDDM ma usa il tema di default.
Aggiungi i file QML e gli assets per attivare il tema custom.
