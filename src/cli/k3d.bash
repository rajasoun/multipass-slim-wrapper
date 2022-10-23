#!/usr/bin/env bash

function _k3d(){
    opt="$2"
    action=$( tr '[:upper:]' '[:lower:]' <<<"$opt" )
    check_preconditions "multipass"
case $action in
    setup)
      display_runnning_vms "setup"
      get_vm_name
      launch_docker_vm "$VM_NAME" 
      add_google_dns "$VM_NAME"
      multipass exec "$VM_NAME" -- docker run hello-world || echo "docker run  ❌"
      multipass exec "$VM_NAME" -- sudo snap install kubectl  --classic
      multipass exec "$VM_NAME" -- sudo snap install helm --classic
      K3D_INSTALL_CMD="curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | K3S_KUBECONFIG_MODE="644" bash -"
      multipass exec "$VM_NAME" -- /bin/bash -c "${K3D_INSTALL_CMD}" || echo "k3d install ❌"
      # Setup our cluster with 2 worker nodes (--agents in k3d command line) and 
      # Expose the HTTP load balancer on the host on port 8080 
      # so that we can interact with our application
      # multipass exec "$VM_NAME" -- k3d cluster create k3s || echo "k3s cluster creation ❌"
      multipass exec "$VM_NAME" -- k3d cluster create k3s-cluster \
                                --api-port 6443 -p 8080:80@loadbalancer \
                                --agents 2 || echo "k3s cluster creation ❌"
      multipass exec "$VM_NAME" -- kubectl cluster-info
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
      GITHUB_URL=https://github.com/kubernetes/dashboard/releases
      VERSION_KUBE_DASHBOARD=$(curl -w '%{url_effective}' -I -L -s -S ${GITHUB_URL}/latest -o /dev/null | sed -e 's|.*/||')
      YAML_MANIFEST=https://raw.githubusercontent.com/kubernetes/dashboard/${VERSION_KUBE_DASHBOARD}/aio/deploy/recommended.yaml
      multipass exec "$VM_NAME"  -- kubectl create -f $YAML_MANIFEST
      VM_MOUNT_DIR="/yaml-manifests"
      mount_dir "$VM_NAME" "${PWD}/iam/admin" $VM_MOUNT_DIR
      multipass exec "$VM_NAME"  --working-directory $VM_MOUNT_DIR  -- kubectl create -f dashboard.admin-user.yml -f dashboard.admin-user-role.yml
      
      token=$(multipass exec "$VM_NAME"  -- kubectl -n kubernetes-dashboard create token admin-user)
      IP=$(multipass info "$VM_NAME" | grep IPv4 | awk '{ print $2 }')

      multipass exec "$VM_NAME"  -- sudo kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard \
                                    10443:443 --address 0.0.0.0 > /dev/null 2>&1 &
      echo "Dashboard URL: https://$IP:10443"
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
