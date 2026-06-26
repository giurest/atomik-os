#!/bin/bash
set -ouex pipefail

## RPMFusion è già installato dal desktop base.
## Installa driver NVIDIA proprietari + configurazione completa per bootc/ostree.

## Trova la versione kernel installata
KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')
echo "→ Kernel rilevato: ${KERNEL_VERSION}"

## Installa kernel-devel per compilare il modulo NVIDIA
dnf install -y kernel-devel-${KERNEL_VERSION}

## Installa driver NVIDIA da RPMFusion
## NB: niente tsflags=noscripts — servono gli scriptlet per la config base
dnf install -y \
    akmod-nvidia \
    xorg-x11-drv-nvidia \
    xorg-x11-drv-nvidia-cuda \
    nvidia-gpu-firmware

## Compila il modulo kernel NVIDIA
echo "→ Compilazione modulo NVIDIA per kernel ${KERNEL_VERSION}..."
akmods --force --kernels ${KERNEL_VERSION}

## Verifica che il modulo sia stato compilato
if find /usr/lib/modules/${KERNEL_VERSION} -name "nvidia.ko*" 2>/dev/null | grep -q .; then
    echo "✓ Modulo NVIDIA compilato con successo"
else
    echo "✗ Modulo NVIDIA NON trovato — build interrotta"
    find /usr/lib/modules/${KERNEL_VERSION} -name "nvidia*" 2>/dev/null || true
    exit 1
fi

## ── Configurazione NVIDIA (il pezzo che mancava) ────────────────────────────

## 1) Blacklist nouveau
cat > /etc/modprobe.d/blacklist-nouveau.conf << 'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

## 2) Abilita modeset nvidia-drm (necessario per Wayland/niri)
cat > /etc/modprobe.d/nvidia.conf << 'EOF'
options nvidia-drm modeset=1 fbdev=1
EOF

## 3) Includi i moduli nvidia nell'initramfs, escludi nouveau
cat > /etc/dracut.conf.d/nvidia.conf << 'EOF'
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
omit_drivers+=" nouveau "
EOF

## 4) Kernel arguments via bootc kargs.d (modo corretto su bootc/ostree)
mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/00-nvidia.toml << 'EOF'
kargs = [
    "rd.driver.blacklist=nouveau",
    "modprobe.blacklist=nouveau",
    "nvidia-drm.modeset=1",
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
]
EOF

## 5) Servizi nvidia (sospensione/risveglio + persistenced)
systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service 2>/dev/null || true
systemctl enable nvidia-persistenced.service 2>/dev/null || true

## 6) Rigenera initramfs includendo i moduli nvidia
##    --add ostree obbligatorio su bootc; --omit i18n evita errore /root in container
dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible --zstd \
    --add ostree --omit i18n \
    -f "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"

## Rimuovi kernel-devel (non serve in produzione)
dnf remove -y kernel-devel-${KERNEL_VERSION} 2>/dev/null || true

## Pulizia
dnf clean all