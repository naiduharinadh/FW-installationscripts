#!/bin/bash
set -e

echo "Updating system..."
sudo apt update -y && sudo apt upgrade -y

echo "Installing KVM and dependencies..."
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager net-tools

echo "Enabling and starting libvirtd..."
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

echo "Verifying KVM installation..."
lsmod | grep kvm || echo "KVM module not loaded, check instance support!"

echo "Creating network bridge (br0) for internet access..."
sudo tee /etc/netplan/01-netcfg.yaml > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: yes
  bridges:
    br0:
      interfaces: [eth0]
      dhcp4: yes
EOF

echo "Applying network configuration..."
sudo netplan apply

echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

echo "Setting up NAT for outbound internet..."
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i br0 -o eth0 -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "Persisting iptables rules..."
sudo apt install -y iptables-persistent
sudo netfilter-persistent save

echo "Preparing FortiGate VM directory..."
mkdir -p ~/fortigate-vm
cd ~/fortigate-vm

echo "Checking for FortiGate image..."
if [[ ! -f fortigate.qcow2 ]]; then
  echo "❌ fortigate.qcow2 not found in ~/fortigate-vm. Please upload it first!"
  exit 1
fi

echo "Launching FortiGate Firewall VM..."
sudo qemu-system-x86_64 \
  -name fortigate-fw \
  -m 2048 \
  -smp 2 \
  -drive file=fortigate.qcow2,format=qcow2,if=virtio \
  -netdev bridge,id=net0,br=br0 \
  -device virtio-net,netdev=net0 \
  -nographic \
  -enable-kvm

echo "✅ FortiGate VM started!"
echo "Console access: already attached (nographic mode)"
