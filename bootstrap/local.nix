{
  systemArgs,
  pkgs,
  lib,
  ...
}: {
  services.configured = {
    kmscon = {
      autologin = true;
      enable = true;
    };
  };

  /*
  Use networkmanager instead of install-iso default wpa_supplicant
  */
  networking.wireless.enable = lib.mkForce false;

  boot.initrd.systemd.emergencyAccess = lib.mkForce false;

  environment = {
    systemPackages = [
      (pkgs.writeShellScriptBin "help" ''
        RESET="\\e[0m"
        GREEN="\\e[32m"
        CYAN="\\e[36m"
        YELLOW="\\e[33m"
        BLUE="\\e[34m"

        echo -e "$GREEN  Welcome to the NixISO installation process :)$RESET"
        echo ""
        echo -e "   ''${BLUE}1.''${RESET} First, run$CYAN nmtui$RESET to connect to a network (if not using ETH)."
        echo -e "   ''${BLUE}2.''${RESET} Then, use$CYAN lsblk$RESET to determine the disk setup"
        echo -e "      and write it into the $YELLOW disks.nix $RESET file for your host."
        echo -e "   ''${BLUE}3.''${RESET} You can use$CYAN get_config$RESET to pull your config."
        echo -e "   ''${BLUE}4.''${RESET} Once that is done, run disko (don't forget to set your"
        echo -e "      LUKS password in$YELLOW /tmp/secret.key$RESET though)$RESET:"
        echo ""
        echo -e "      $CYAN do_disko$YELLOW path/to/disks.nix$RESET"
        echo ""
        echo -e "   ''${BLUE}5.''${RESET} Now you can generate your hardware configuration using"
        echo -e "      the command$CYAN make_config$RESET."
        echo -e "   ''${BLUE}6.''${RESET} Finally, install the OS (whilst inside the config directory):"
        echo ""
        echo -e "      $CYAN sudo nixos-install --flake .$YELLOW#HOSTNAME $RESET"
        echo ""
        echo -e "   ''${BLUE}7.''${RESET} Note that you might have to disable secureboot during installation."
        echo ""
      '')
      (pkgs.writeShellScriptBin "do_disko" ''
        sudo nix run github:nix-community/disko/latest -- --mode destroy,format,mount $@
      '')
      (pkgs.writeShellScriptBin "make_config" ''
        if [ -f "./hardware-configuration.nix" ]; then
          read -p "hardware-configuration.nix already exists. Overwrite? (y/N) " -n 1 -r
          echo
          if [[ ! "$REPLY" =~ ^[yY]$ ]]; then
            echo "Aborted."
            exit 1
          fi
          echo "Continuing..."
        fi
        sudo nixos-generate-config --no-filesystems --root /mnt
        sudo cp /mnt/etc/nixos/hardware-configuration.nix ./
        sudo chown ${systemArgs.username} ./hardware-configuration.nix
        git add ./hardware-configuration.nix
      '')
      (pkgs.writeShellScriptBin "get_config" ''
        git clone https://github.com/m4r1vs/nixos
        cd nixos
      '')
    ];
  };

  system = {
    nixos.label = systemArgs.hostname + ".niveri.dev";
  };
}
