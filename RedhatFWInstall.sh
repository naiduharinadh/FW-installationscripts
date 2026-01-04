#!/bin/bash
set -e

echo "Updating system..."
sudo dnf update -y

echo "Installing KVM and virtualization packages..."
sudo dnf install -y @virtualization qemu-kvm libvirt virt-install bridge-utils net-tools

echo "Enabling and starting libvirtd..."
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

echo "Verifying KVM installation..."
lsmod | grep kvm || echo "⚠ KVM module not loaded, check CPU virtualization support!"

echo "Creating network bridge (br0) for internet access..."
sudo nmcli connection add type bridge ifname br0 con-name br0
sudo nmcli connection modify br0 ipv4.method auto

echo "Adding eth0 to bridge..."
sudo nmcli connection modify eth0 master br0 slave-type bridge
sudo nmcli connection up br0 || true
sudo nmcli connection up eth0 || true

echo "Enabling IP forwarding..."
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

echo "Setting up NAT for outbound internet..."
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i br0 -o eth0 -j ACCEPT
sudo iptables -A FORWARD -i eth0 -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT

echo "Persisting iptables rules..."
sudo dnf install -y iptables-services
sudo systemctl enable iptables
sudo service iptables save

echo "Preparing FortiGate VM directory..."
mkdir -p ~/fortigate-vm
cd ~/fortigate-vm

echo "Checking for FortiGate image..."
if [[ ! -f ~/fortigate-vm/fortigate.qcow2 ]]; then
  echo "❌ FortiGate image not found at ~/fortigate-vm/fortigate.qcow2"
  echo "Please upload the image and rename it to fortigate.qcow2 first!"
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






chmod +x setup-fortigate-rhel.sh
mkdir -p ~/fortigate-vm
cd ~/fortigate-vm

# Upload your FortiGate image here and ensure the name is:
# fortigate.qcow2
# (example rename)
mv your-uploaded-image.qcow2 fortigate.qcow2

cd ~
./setup-fortigate-rhel.sh



