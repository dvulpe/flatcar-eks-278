#!/bin/bash

set -euo pipefail

mkdir -p /data/kubelet
docker run --rm --network host -v /data/kubelet:/data amazon/aws-cli s3 sync \
  s3://amazon-eks/1.17.12/2020-11-02/bin/linux/amd64/ /data/

mkdir -p /opt/cni/bin /etc/cni/net.d

tar -C /opt/cni/bin -zxvf /data/kubelet/cni-amd64-v0.6.0.tgz
tar -C /opt/cni/bin -zxvf /data/kubelet/cni-plugins-linux-amd64-v0.8.6.tgz

chmod +x /data/kubelet/kubelet
chmod +x /data/kubelet/aws-iam-authenticator
