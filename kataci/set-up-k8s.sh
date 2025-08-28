#!/bin/bash

set -e

swapoff -a
# Pass bridged IPv4 traffic to iptables’ chains. This is a requirement for some CNI plugins to work
sysctl net.bridge.bridge-nf-call-iptables=1

# flannel 要求指定该 pod-network-cidr
# 指定 image-repository 以使用国内镜像
kubeadm init --pod-network-cidr=10.244.0.0/16 --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

kubectl taint nodes --all node-role.kubernetes.io/master-
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
