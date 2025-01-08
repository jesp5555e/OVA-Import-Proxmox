#!/bin/bash

# Indtast parametre
OVA_FILE="/mnt/pve/ISO-Jesper/template/iso/20250108T095845Z - Ubuntu 22.04 to XO.ova"   # Sti til din OVA-fil
VM_ID="100"                     # ID for den nye VM i Proxmox
VM_NAME="Ubuntu-to-docker-and-guacamole"   # Navn på den nye VM
STORAGE="local-lvm"            # Navn på storage i Proxmox

# Kontroller, at OVA-filen eksisterer
if [ ! -f "$OVA_FILE" ]; then
  echo "OVA file not found: $OVA_FILE"
  exit 1
fi

# Udpak OVA-filen
TMP_DIR=$(mktemp -d)
echo "Extracting OVA file to $TMP_DIR..."
tar -xf "$OVA_FILE" -C "$TMP_DIR"

# Find VMDK-filen
VMDK_FILE=$(find "$TMP_DIR" -name "*.vmdk" | head -n 1)
if [ -z "$VMDK_FILE" ]; then
  echo "No VMDK file found in OVA."
  exit 1
fi

echo "Found VMDK file: $VMDK_FILE"

# Konverter VMDK til QCOW2
QCOW2_FILE="$TMP_DIR/disk.qcow2"
echo "Converting VMDK to QCOW2..."
qemu-img convert -f vmdk -O qcow2 "$VMDK_FILE" "$QCOW2_FILE"

# Opret en ny VM i Proxmox
echo "Creating VM $VM_ID..."
pct create $VM_ID "$QCOW2_FILE" --storage $STORAGE
qm create $VM_ID --name "$VM_NAME" --memory 2048 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci --boot c --ostype l26

# Upload QCOW2 til Proxmox storage
echo "Uploading disk to Proxmox storage..."
qm importdisk $VM_ID "$QCOW2_FILE" "$STORAGE"

# Tilknyt disken til VM
echo "Attaching disk to VM..."
qm set $VM_ID --scsi0 "$STORAGE:vm-$VM_ID-disk-0"

# Konfigurer VM'en til at boote fra disken
echo "Configuring boot disk..."
qm set $VM_ID --bootdisk scsi0

# Ryd op
echo "Cleaning up temporary files..."
rm -rf "$TMP_DIR"

echo "OVA import complete! VM ID $VM_ID is ready."
