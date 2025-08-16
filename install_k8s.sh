#!/bin/bash
set -e

echo "=== Cập nhật hệ thống ==="
sudo apt update -y && sudo apt upgrade -y

echo "=== Tạo user devops (nếu chưa có) ==="
if id "devops" &>/dev/null; then
  echo "User devops đã tồn tại"
else
  sudo adduser --disabled-password --gecos "" devops
  echo "devops ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/devops
fi

echo "=== Tắt swap ==="
sudo swapoff -a
sudo sed -i '/swap.img/s/^/#/' /etc/fstab

echo "=== Cấu hình module kernel ==="
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

echo "=== Cấu hình sysctl cho Kubernetes ==="
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

echo "=== Cài đặt gói cần thiết và thêm kho Docker ==="
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

echo "=== Cài đặt containerd ==="
sudo apt update -y
sudo apt install -y containerd.io

echo "=== Cấu hình containerd ==="
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

echo "=== Thêm kho lưu trữ Kubernetes ==="
sudo mkdir -p /etc/apt/keyrings
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "=== Cài đặt Kubernetes (kubelet, kubeadm, kubectl) ==="
sudo apt update -y
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "=== Hoàn tất cài đặt Kubernetes environment ==="
