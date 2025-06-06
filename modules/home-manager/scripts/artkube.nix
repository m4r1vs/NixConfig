{pkgs, ...}: {
  artkube =
    pkgs.writeShellScriptBin "artkube"
    ''
      VPN_NAME="FBI"

      export PATH=${pkgs.lib.makeBinPath [
        pkgs.networkmanager
        pkgs.kubectl
        pkgs.coreutils
        pkgs.wl-clipboard
        pkgs.brave
        pkgs.terraform
      ]}:$PATH

      is_vpn_active() {
        nmcli connection show --active | grep -q "$VPN_NAME"
      }

      is_ssh_running() {
        pgrep -x "ssh" > /dev/null 2>&1
      }

      start_ssh_forward() {
        scp k8user@134.100.7.117:/home/k8user/.kube/config /home/mn/.kube/config > /dev/null
        echo -e "👾 Copied \e[35mk8user@134.100.7.117\e[0m:\e[35m/home/k8user/.kube/config\e[0m to \e[35m/home/mn/.kube/config\e[0m"
        ssh -N -L 6443:127.0.0.1:6443 k8user@134.100.7.117 > /dev/null &
        echo -e "👾 Forwarding \e[32m6443\e[0m from \e[32m133.100.7.117\e[0m to \e[33mlocalhost\e[0m"

        sleep 1

        if kubectl get ns > /dev/null 2>&1; then
          if kubectl get ns argocd > /dev/null 2>&1; then
            echo -e "👾 k8s namespace \e[35margocd\e[0m exists, copied admin password and opening the webinterface..."
            kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d | wl-copy
            brave "https://argocd.artkube.informatik.uni-hamburg.de/" &> /dev/null
          else
            echo -e "👾 k8s namespace \e[35margocd\e[0m does not exist."
            cd /home/mn/Documents/projekt-kubernetes/cluster/
            echo -e "👾 running \e[35mterraform init -upgrade\e[0m in the background.."
            terraform init -upgrade > /dev/null
            echo -e "👾 Now \e[35mterraform apply\e[0m in the foreground"
            terraform apply
          fi
        else
          echo -e "👾 Could not get kubernetes namespaces. \e[3mSomething's wrong, I can feel it.\e[0m"
        fi
      }

      stop_ssh_forward() {
        pkill -x "ssh" > /dev/null
        echo "👾 Stopped SSH forwarding"
      }

      activate_vpn() {
        nmcli connection up "$VPN_NAME" > /dev/null
        if [ $? -eq 0 ]; then
          echo -e "👾 Activated VPN (\e[36m$VPN_NAME\e[0m)"
        else
          echo -e "👾 Failed to activate VPN (\e[36m$VPN_NAME\e[0m)"
          exit 1
        fi
      }

      disable_vpn() {
        nmcli connection down "$VPN_NAME" > /dev/null
        if [ $? -eq 0 ]; then
          echo -e "👾 Disabled VPN (\e[36m$VPN_NAME\e[0m)"
        else
          echo -e "👾 Failed to disable VPN (\e[36m$VPN_NAME\e[0m)"
          exit 1
        fi
      }

      if is_ssh_running; then
        if is_vpn_active; then
          stop_ssh_forward
          disable_vpn
        else
          stop_ssh_forward
        fi
      else
        if is_vpn_active; then
          disable_vpn
        else
          activate_vpn
          start_ssh_forward
        fi
      fi
    '';
}
