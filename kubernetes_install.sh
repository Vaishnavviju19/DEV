
#!/usr/bin/env bash
set -euo pipefail

MODE=${1:-"none"}
echo ">>> Starting Kubernetes setup for mode = $MODE"

############################################################
# 1. BASIC SYSTEM PREPARATION
############################################################

echo ">>> Updating system packages..."
sudo apt update -y
sudo apt install -y curl apt-transport-https ca-certificates gnupg lsb-release software-properties-common

echo ">>> Disabling swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo ">>> Setting sysctl params required by Kubernetes"
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF
sudo sysctl --system

############################################################
# 2. INSTALL & CONFIGURE CONTAINERD
############################################################

echo ">>> Installing containerd..."
sudo apt install -y containerd

echo ">>> Creating containerd config..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

echo ">>> Setting containerd cgroup driver to systemd..."
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

echo ">>> Restarting containerd..."
sudo systemctl restart containerd
sudo systemctl enable containerd

############################################################
# 3. FIX BROKEN OLD KUBERNETES REPOS
############################################################

echo ">>> Removing old Kubernetes repo files..."
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/sources.list.d/k8s.list
sudo rm -f /etc/apt/sources.list.d/*kubernetes*
sudo rm -f /etc/apt/sources.list.d/isv:kubernetes*
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg || true

############################################################
# 4. INSTALL NEW KUBERNETES REPO (pkgs.k8s.io)
############################################################

echo ">>> Adding official Kubernetes repository (v1.30)..."
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

sudo apt update -y

############################################################
# 5. INSTALL KUBERNETES
############################################################

echo ">>> Installing kubeadm, kubelet, kubectl"
sudo apt install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl

############################################################
# 6. MASTER NODE SETUP
############################################################

if [[ "$MODE" == "master" ]]; then
    echo ">>> Initializing Kubernetes master node..."

    sudo kubeadm init --pod-network-cidr=192.168.0.0/16


    echo ">>> Configuring kubectl for current user"
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    echo ">>> Installing calico CNI"
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.1/manifests/calico.yaml

    echo ""
    echo ">>> Master setup complete!"
    echo ">>> COPY THIS kubeadm join COMMAND AND RUN ON WORKER NODES:"
    kubeadm token create --print-join-command
    exit 0
fi

############################################################
# 7. WORKER NODE SETUP
############################################################

if [[ "$MODE" == "worker" ]]; then
    echo ""
    echo ">>> Worker node setup complete!"
    echo ">>> Now run the kubeadm join command from master here."
    echo ""
    exit 0
fi

echo ">>> Invalid mode. Use:  ./k8s-setup.sh master   OR   ./k8s-setup.sh worker"
