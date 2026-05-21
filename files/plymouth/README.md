# Tema Plymouth — Atomik OS

## File necessari in questa cartella

```
files/plymouth/
├── atomik.plymouth          ← descrittore tema (già creato)
├── atomik-logo.png          ← logo principale (suggerito: 300x300 PNG)
├── background.png           ← sfondo boot (1920x1080 PNG)
└── progress_dot_on.png      ← indicatore progress (opzionale)
    progress_dot_off.png
```

## atomik.plymouth (da creare)

```ini
[Plymouth Theme]
Name=Atomik
Description=Atomik OS boot theme
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/atomik
ScriptFile=/usr/share/plymouth/themes/atomik/atomik.script
```

## atomik.script (da creare)

Script Plymouth per animazione boot. Esempio minimalista:

```
logo.image = Image("atomik-logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetX(Window.GetWidth() / 2 - logo.image.GetWidth() / 2);
logo.sprite.SetY(Window.GetHeight() / 2 - logo.image.GetHeight() / 2);

background.image = Image("background.png");
background.sprite = Sprite(background.image);
background.sprite.SetZ(-100);
```

## Risorse utili

- https://wiki.archlinux.org/title/Plymouth
- https://www.freedesktop.org/wiki/Software/Plymouth/
