#!/bin/bash

set -e

swapoff -a
# Pass bridged IPv4 traffic to iptables’ chains. This is a requirement for some CNI plugins to work
if [ "$(id -u)" -ne 0 ]; then
    echo "please use root"
    exit 1
fi

# 配置文件路径
CONFIG_FILE="/etc/sysctl.d/99-ip-forward.conf"

# 创建或更新配置文件
echo "正在配置IP转发..."
cat > "$CONFIG_FILE" << EOF
# enable IPv4 forwarding
net.ipv4.ip_forward=1

# enable IPv6 forwarding
net.ipv6.conf.all.forwarding=1
EOF
sysctl --system

# flannel 要求指定该 pod-network-cidr
# 指定 image-repository 以使用国内镜像
#kubeadm init -v=5 --pod-network-cidr=10.244.0.0/16 --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers
kubeadm init -v=5 --pod-network-cidr=10.244.0.0/16

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
