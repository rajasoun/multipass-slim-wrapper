#!/usr/bin/env bash

function _microk8s(){
    opt="$2"
    action=$( tr '[:upper:]' '[:lower:]' <<<"$opt" )
case $action in
    setup)
      _multipass "$@"
      multipass exec "$VM_NAME" -- sudo snap install microk8s --classic --channel=1.25/stable || echo "microk8s install ❌"
      multipass exec "$VM_NAME" -- sudo usermod -a -G microk8s ubuntu || echo "usermod  ❌"
      multipass exec "$VM_NAME" -- sudo snap alias microk8s.kubectl kubectl || echo "snap alias  ❌"
      multipass exec "$VM_NAME" -- microk8s status --wait-ready || echo "status  ❌"
      multipass exec "$VM_NAME" -- microk8s enable dashboard || echo "dashboard  ❌"
      multipass exec "$VM_NAME" -- kubectl get pods --all-namespaces || echo "pods  ❌"
      multipass exec "$VM_NAME" -- kubectl cluster-info || echo "cluster info  ❌"

      # enable kubeconfig on host system
      multipass exec "$VM_NAME" -- microk8s config > kubeconfig/.admin.kubeconfig  || echo "kubeconfig  ❌"
      ;;
    shell)
      _multipass "$@"
      ;;
    status)
      echo -e "\n${GREEN}Nodes:${NC}"
      multipass exec "$VM_NAME" -- kubectl get nodes || echo "pods  ❌"
      echo -e "\n${GREEN}Services:${NC}"
      multipass exec "$VM_NAME" -- kubectl get services || echo "pods  ❌"
      echo -e "\n${GREEN}PODs:${NC}"
      multipass exec "$VM_NAME" -- kubectl get pods --all-namespaces || echo "pods  ❌"
      ;;
    pods)
      multipass exec "$VM_NAME" -- kubectl get pods --all-namespaces || echo "pods  ❌"
      ;;
    dashboard)
      token=$(multipass exec "$VM_NAME" -- kubectl describe secret -n kube-system microk8s-dashboard-token | grep -E '^token' | awk '{print $2}')
      IP=$(multipass info "$VM_NAME" | grep IPv4 | awk '{ print $2 }')
      multipass exec "$VM_NAME"  -- sudo iptables -P FORWARD ACCEPT || echo "iptables update ❌"
      multipass exec "$VM_NAME"  -- kubectl port-forward -n kube-system service/kubernetes-dashboard \
                                    10443:443 --address 0.0.0.0 > /dev/null 2>&1 &
      echo -e "\n${BOLD}Dashboard URL:${NC} https://$IP:10443"
      echo -e "\n$token"
      ;;
    clean)
      _multipass "$@"
      ;;
    *)
      echo "${RED}Usage: ./assist <command>${NC}"
cat <<-EOF
Commands:
---------
  setup       -> Install and Configure microk8s
  dashboard   -> Access k8s Dashboard
  pods        -> List Running PODs
  clean       -> Clean multipass VM
EOF
    ;;
esac
}
