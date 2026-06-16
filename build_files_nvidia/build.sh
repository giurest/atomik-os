#!/bin/bash
set -ouex pipefail

## RPMFusion è già installato dal desktop base.
## Installa driver NVIDIA proprietari.

## Trova la versione kernel installata
KERNEL_VERSION=$(rpm -q kernel --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')
echo "→ Kernel rilevato: ${KERNEL_VERSION}"

## Installa kernel-devel per compilare il modulo NVIDIA
dnf install -y kernel-devel-${KERNEL_VERSION}

## Installa driver NVIDIA da RPMFusion
dnf install -y \
    akmod-nvidia \
    xorg-x11-drv-nvidia \
    xorg-x11-drv-nvidia-cuda \
    nvidia-gpu-firmware

## Compila il modulo kernel NVIDIA
echo "→ Compilazione modulo NVIDIA per kernel ${KERNEL_VERSION}..."
akmods --force --kernels ${KERNEL_VERSION}

## Verifica che il modulo sia stato compilato
if [ -f /usr/lib/modules/${KERNEL_VERSION}/extra/nvidia/nvidia.ko* ]; then
    echo "✓ Modulo NVIDIA compilato con successo"
else
    echo "⚠ Modulo NVIDIA non trovato, verifica manualmente"
    find /usr/lib/modules/${KERNEL_VERSION} -name "nvidia*" 2>/dev/null || true
fi

## Rimuovi kernel-devel (non serve in produzione)
dnf remove -y kernel-devel-${KERNEL_VERSION} 2>/dev/null || true

## Pulizia
dnf clean all
