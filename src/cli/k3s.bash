#!/usr/bin/env bash

function _k3s(){
    opt="$2"
    action=$( tr '[:upper:]' '[:lower:]' <<<"$opt" )
    check_preconditions "multipass"
case $action in
    setup)
      for VM_NAME in k3s-master k3s-worker-1 k3s-worker-2;do
        launch_vm "$VM_NAME"
        add_google_dns "$VM_NAME"
      done

      display_runnning_vms "setup"
      
      # Init cluster on k3s-master
      multipass exec k3s-master -- bash -c "curl -sfL https://get.k3s.io | sh -" 
      # Get k3s-master IP
      IP=$(multipass info k3s-master | grep IPv4 | awk '{print $2}')
      # Get Token used to join nodes
      TOKEN=$(multipass exec k3s-master sudo cat /var/lib/rancher/k3s/server/node-token)

      # Join k3s-worker-1
      multipass exec k3s-worker-1 -- \
                  bash -c "curl -sfL https://get.k3s.io | K3S_URL=\"https://$IP:6443\" K3S_TOKEN=\"$TOKEN\" sh -"

      # Join k3s-worker-2
      multipass exec k3s-worker-2 -- \
                  bash -c "curl -sfL https://get.k3s.io | K3S_URL=\"https://$IP:6443\" K3S_TOKEN=\"$TOKEN\" sh -"


      # Get cluster's configuration
      multipass exec k3s-master -- sudo cat /etc/rancher/k3s/k3s.yaml > kubeconfig/.k3s.yaml

      # Set k3s-master's external IP in the configuration file
      sed -i '' "s/127.0.0.1/$IP/" kubeconfig/.k3s.yaml

      kubectl label node k3s-master  node-role.kubernetes.io/master="master" 
      kubectl label node k3s-worker-1 node-role.kubernetes.io/node="worker"
      kubectl label node k3s-worker-2 node-role.kubernetes.io/node="worker"

      kubectl taint node k3s-master node-role.kubernetes.io/master=effect:NoSchedule

      # We'r all set
      echo
      echo "K3s cluster is ready !"
      echo
      echo "Running the following command to set the current context:"
      echo "$ export KUBECONFIG=$PWD/kubeconfig/.k3s.yaml"
      echo
      export KUBECONFIG=$PWD/kubeconfig/.k3s.yaml
      echo
      ;;
    shell)
      _multipass "$@"
      ;;
    status)
      echo -e "\n${GREEN}Nodes:${NC}"
      export KUBECONFIG=$PWD/kubeconfig/.k3s.yaml
      kubectl get nodes || echo "pods  ❌"
      echo -e "\n${GREEN}Services:${NC}"
      kubectl get services --all-namespaces || echo "pods  ❌"
      echo -e "\n${GREEN}PODs:${NC}"
      kubectl get pods --all-namespaces -o wide || echo "pods  ❌"
      ;;
    pods)
      export KUBECONFIG=$PWD/kubeconfig/.k3s.yaml
      kubectl get pods --all-namespaces || echo "pods  ❌"
      ;;
    dashboard)
      export KUBECONFIG=$PWD/kubeconfig/.k3s.yaml
      GITHUB_URL=https://github.com/kubernetes/dashboard/releases
      VERSION_KUBE_DASHBOARD=$(curl -w '%{url_effective}' -I -L -s -S ${GITHUB_URL}/latest -o /dev/null | sed -e 's|.*/||')
      YAML_MANIFEST=https://raw.githubusercontent.com/kubernetes/dashboard/${VERSION_KUBE_DASHBOARD}/aio/deploy/recommended.yaml
      kubectl create -f $YAML_MANIFEST
      kubectl create -f iam/admin/dashboard.admin-user.yml -f iam/admin/dashboard.admin-user-role.yml
      
      token=$(kubectl -n kubernetes-dashboard create token admin-user)

      kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 10443:443 --address 0.0.0.0 > /dev/null 2>&1 &
      echo -e "${BOLD}Dashboard URL:${NC} https://localhost:10443"
      echo "$token"
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
  shell       -> Enter Shell
  dashboard   -> Access k8s Dashboard
  pods        -> List Running PODs
  clean       -> Clean multipass VM
EOF
    ;;
esac
}
