#!/usr/bin/env bash

set -eo pipefail
IFS=$'\n\t'

CPU=${CPU:-"2"}
MEMORY=${MEMORY:-"2G"}
DISK=${DISK:-"4G"}
VM_NAME=${VM_NAME:-"microk8s"}
export CPU MEMORY DISK VM_NAME

export "$(< kubeconfig/env  xargs)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/src/load.bash"

opt="$1"
choice=$( tr '[:upper:]' '[:lower:]' <<<"$opt" )
case $choice in
    multipass) _multipass "$@" ;;
     microk8s)  _microk8s "$@" ;;
          k3d)       _k3d "$@" ;;
          k3s)       _k3s "$@" ;;
    *)
      echo "${RED}Usage: ./assist <command>${NC}"
cat <<-EOF
Commands:
---------
  multipass    -> Manage multipass - virtualization orchestrator
  microk8s     -> Manage microk8s  - k8s orchestrator
      k3d      -> Manage k3d - Kubernetes distribution in docker
      k3s      -> Manage k3s 3 node Cluster 
EOF
    ;;
esac
