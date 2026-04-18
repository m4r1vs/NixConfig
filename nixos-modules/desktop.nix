{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.configured.desktop;
  isX86 = systemArgs.system == "x86_64-linux";
in {
  options.configured.desktop = {
    enable = mkEnableOption "Enable a Desktop Environment";
    windowManagers = {
      hyprland = {
        enable = mkEnableOption "Enable Hyprland Specialisation";
        default = mkOption {
          type = types.bool;
          default = true;
          description = "Make Hyprland the default";
        };
      };
      i3 = {
        enable = mkEnableOption "Enable i3 (X Window Server) Specialisation";
        default = mkOption {
          type = types.bool;
          default = false;
          description = "Make i3 the default";
        };
      };
      gamescope = {
        enable = mkEnableOption "Enable Gamescope (Steam Big Picture) Specialisation";
        default = mkOption {
          type = types.bool;
          default = false;
          description = "Make Gamescope the default";
        };
      };
    };
  };
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion =
          (count (x: x) [
            cfg.windowManagers.hyprland.default
            cfg.windowManagers.i3.default
            cfg.windowManagers.gamescope.default
          ])
          <= 1;
        message = "Only one window manager can be the default.";
      }
      {
        assertion = cfg.windowManagers.hyprland.default -> cfg.windowManagers.hyprland.enable;
        message = "Hyprland is set as default but not enabled.";
      }
      {
        assertion = cfg.windowManagers.i3.default -> cfg.windowManagers.i3.enable;
        message = "i3 is set as default but not enabled.";
      }
      {
        assertion = cfg.windowManagers.gamescope.default -> cfg.windowManagers.gamescope.enable;
        message = "Gamescope is set as default but not enabled.";
      }
    ];

    environment.pathsToLink = ["/share/xdg-desktop-portal" "/share/applications"];

    configured = {
      limine.enable = true;
      system-sounds.enable = true;
    };

    specialisation = {
      "Hyprland (Wayland)".configuration = mkIf cfg.windowManagers.hyprland.enable {
        configured.hyprland.enable = lib.mkForce true;
        configured.i3.enable = lib.mkForce false;
        configured.gamescope.enable = lib.mkForce false;
      };
      "i3 (X Window System)".configuration = mkIf cfg.windowManagers.i3.enable {
        configured.hyprland.enable = lib.mkForce false;
        configured.i3.enable = lib.mkForce true;
        configured.gamescope.enable = lib.mkForce false;
      };
      "Steam Gamescope (Wayland)".configuration = mkIf cfg.windowManagers.gamescope.enable {
        configured.hyprland.enable = lib.mkForce false;
        configured.i3.enable = lib.mkForce false;
        configured.gamescope.enable = lib.mkForce true;
      };
    };

    configured.hyprland.enable = cfg.windowManagers.hyprland.enable && cfg.windowManagers.hyprland.default;
    configured.i3.enable = cfg.windowManagers.i3.enable && cfg.windowManagers.i3.default;
    configured.gamescope.enable = cfg.windowManagers.gamescope.enable && cfg.windowManagers.gamescope.default;

    networking.extraHosts = ''
      127.0.0.1 artpc17
    '';

    # Fix libstrongswan not working due to missing config file
    environment.etc."strongswan.conf" = {
      enable = true;
      user = "root";
      group = "root";
      mode = "0644";
      text = "";
    };

    services = {
      configured.kmscon.enable = true;

      /*
      Touchpad support
      */
      libinput = {
        enable = true;
        touchpad = {
          tapping = true;
          naturalScrolling = true;
          scrollMethod = "twofinger";
          disableWhileTyping = true;
        };
      };

      /*
      CUPS
      */
      printing = {
        enable = true;
        drivers = with pkgs; [
          brlaser
        ];
      };

      /*
      Auto-Discovery of
      network devices
      */
      avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

      /*
      Audio
      */
      pipewire = {
        enable = true;
        raopOpenFirewall = true;
        pulse.enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        wireplumber = {
          enable = true;
        };
        extraConfig.pipewire = {
          "10-airplay" = {
            "context.modules" = [
              {
                name = "libpipewire-module-raop-discover";
              }
            ];
          };
        };
      };

      /*
      Misc
      */
      dbus.enable = true;
      blueman.enable = true;
    };

    security = {
      polkit.enable = true;
      rtkit.enable = true;
    };

    boot = {
      binfmt.emulatedSystems =
        if isX86
        then ["aarch64-linux"]
        else ["x86_64-linux"];
      initrd = {
        verbose = false;
        systemd.enable = true;
      };
      consoleLogLevel = 0;
      plymouth = {
        enable = true;
        theme = "owl"; # rings, abstract_ring and colorful_sliced also good
        themePackages = with pkgs; [
          (adi1090x-plymouth-themes.override {
            selected_themes = ["owl"];
          })
        ];
      };
      kernelParams = [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "loglevel=3"
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
      ];
    };

    networking = {
      firewall = {
        allowedTCPPortRanges = [
          {
            # KDE Connect
            from = 1714;
            to = 1764;
          }
        ];
        allowedUDPPortRanges = [
          {
            # Apple AirPlay
            from = 6001;
            to = 6002;
          }
          {
            # KDE Connect
            from = 1714;
            to = 1764;
          }
        ];
      };
    };

    hardware = lib.mkIf isX86 {
      bluetooth = {
        enable = true;
        powerOnBoot = true;
        settings = {
          General = {
            Name = systemArgs.hostname;
            ControllerMode = "dual";
            FastConnectable = "true";
            Experimental = "true";
          };
          Policy = {AutoEnable = "true";};
          LE = {EnableAdvMonInterleaveScan = "true";};
        };
      };
    };

    virtualisation = lib.mkIf isX86 {
      spiceUSBRedirection.enable = true;
      libvirtd.enable = true;
    };

    programs = {
      virt-manager.enable = isX86;
      dconf.enable = true;
      steam = lib.mkIf isX86 {
        enable = true;
        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
      };
      kdeconnect.enable = true;
      _1password.enable = true;
      _1password-gui = {
        enable = true;
        polkitPolicyOwners = [systemArgs.username];
      };
    };

    environment = {
      systemPackages = with pkgs; [
        bibata-cursors
        (runCommandLocal "bibata-cursor-default-theme" {} ''
          mkdir -p $out/share/icons
          ln -s ${bibata-cursors}/share/icons/Bibata-Modern-Ice $out/share/icons/default
        '')
        kdePackages.kwallet
        qemu
        quickemu
      ];
    };
  };
}
