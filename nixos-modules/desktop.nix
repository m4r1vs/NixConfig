{
  lib,
  config,
  pkgs,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.configured.desktop;
  inherit (config.configured.host) isX86;
  rootIsBtrfs = (config.fileSystems."/".fsType or "") == "btrfs";
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

    programs.keypress-visualizer = {
      enable = true;
      settings = {
        mappings = {
          LEFTCTRL = "CTRL";
          RIGHTCTRL = "CTRL";
        };
        appearance = {
          font_size = 52;
          anchor = "top";
          max_keys = 2;
        };
      };
    };

    configured = {
      limine.enable = true;
      system-sounds.enable = true;
    };

    specialisation = {
      "Hyprland (Wayland)".configuration = mkIf cfg.windowManagers.hyprland.enable {
        environment.etc."nixos_active_specialisation".text = "Hyprland (Wayland)";
        configured = {
          hyprland.enable = lib.mkForce true;
          i3.enable = lib.mkForce false;
          gamescope.enable = lib.mkForce false;
        };
      };
      "i3 (X Window System)".configuration = mkIf cfg.windowManagers.i3.enable {
        environment.etc."nixos_active_specialisation".text = "i3 (X Window System)";
        configured = {
          hyprland.enable = lib.mkForce false;
          i3.enable = lib.mkForce true;
          gamescope.enable = lib.mkForce false;
        };
      };
      "Steam Gamescope (Wayland)".configuration = mkIf cfg.windowManagers.gamescope.enable {
        environment.etc."nixos_active_specialisation".text = "Steam Gamescope (Wayland)";
        configured = {
          hyprland.enable = lib.mkForce false;
          i3.enable = lib.mkForce false;
          gamescope.enable = lib.mkForce true;
        };
      };
    };

    configured.hyprland.enable = cfg.windowManagers.hyprland.enable && cfg.windowManagers.hyprland.default;
    configured.i3.enable = cfg.windowManagers.i3.enable && cfg.windowManagers.i3.default;
    configured.gamescope.enable = cfg.windowManagers.gamescope.enable && cfg.windowManagers.gamescope.default;

    services = {
      configured = {
        kmscon.enable = true;
        auto-upgrade.enable = mkDefault true;
        # Lets the firmware notification install updates and restart
        firmware-update.enable = mkDefault config.services.fwupd.enable;
      };

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
        startWhenNeeded = true;
        drivers = with pkgs; [
          brlaser
        ];
      };

      /*
      Audio
      */
      pipewire = {
        enable = true;
        pulse.enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        wireplumber = {
          enable = true;
          # Local bluetooth roles: a2dp_source = send audio to speakers,
          # hfp_ag = use headset microphones, bap_sink/bap_source = LE Audio
          # unicast playback + mic (LC3). Deliberately omits a2dp_sink
          # (receive audio from devices) — speakers that also advertise an
          # Audio Source UUID (e.g. Anker Soundcore Boost) otherwise grab
          # the AVDTP transport in the wrong direction and A2DP playback
          # fails with "Device or resource busy".
          # Leave bluez5.codecs unset so PipeWire keeps all compiled codecs
          # enabled (including HFP mSBC and LC3-SWB; a partial whitelist
          # filters them out and leaves HFP stuck on 8 kHz CVSD).
          extraConfig."51-bluez-roles" = {
            "monitor.bluez.properties" = {
              "bluez5.roles" = ["a2dp_source" "hfp_ag" "bap_sink" "bap_source"];
              "bluez5.enable-sbc-xq" = true;
              "bluez5.enable-msbc" = true;
              "bluez5.enable-hw-volume" = true;
              "bluez5.a2dp.ldac.quality" = "auto";
            };
          };
        };
      };

      /*
      DBus
      */
      dbus = {
        enable = true;
        implementation = "broker";
        packages = with pkgs; [
          gcr
          gnome-settings-daemon
        ];
      };

      /*
      Misc
      */
      gnome.gnome-keyring.enable = true;
      gvfs.enable = true;
      blueman.enable = true;

      /*
      Hardware services, on real machines only (the aarch64 desktop is a VM)
      */

      # UEFI dbx, device and peripheral firmware via LVFS; limine signs
      # fwupd.efi with our sbctl keys
      fwupd.enable = isX86;

      # Authorises USB4/Thunderbolt devices (boltctl)
      hardware.bolt.enable = isX86;

      # SSD health, with a notification when SMART reports trouble
      smartd = mkIf isX86 {
        enable = true;
        extraOptions = ["-i" "3600"];
        notifications.systembus-notify.enable = true;
      };

      /*
      B-Tree FS: a throttled monthly scrub of the root file system
      */
      btrfs.autoScrub = {
        enable = mkDefault rootIsBtrfs;
        interval = mkDefault "monthly";
        limit = mkDefault "250M";
      };

      earlyoom = {
        enable = true;
        enableNotifications = true;
      };

      udev.extraRules = ''
        # Use none scheduler on NVMe drives instead of linux-zen's kyber default
        ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
      '';
    };

    systemd = {
      coredump.settings.Coredump = {
        Storage = "external";
        Compress = "yes";
        MaxUse = "1G";
        ProcessSizeMax = "1G";
      };

      # Replaced by earlyoom, which reacts faster on Hyprland without per-app cgroup scopes
      oomd.enable = false;
    };

    security = {
      polkit.enable = true;
      rtkit.enable = true;
    };

    boot = {
      # linux-zen is marked broken on aarch64
      kernelPackages =
        if isX86
        then pkgs.linuxPackages_zen
        else pkgs.linuxPackages_latest;
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
        "rd.systemd.show_status=false"
        "rd.udev.log_level=3"
        "udev.log_priority=3"
      ];
      kernelModules = ["tcp_bbr"];
      kernel.sysctl = {
        # TCP BBR congestion control with fq pacing
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
      };
      extraModprobeConfig = ''
        # German regulatory domain for Wi-Fi; in the world domain 6 GHz stays off
        options cfg80211 ieee80211_regdom=DE
      '';
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
      wirelessRegulatoryDatabase = true;
      bluetooth = {
        enable = true;
        powerOnBoot = true;
        settings = {
          General = {
            Name = systemArgs.hostname;
            ControllerMode = "dual";
            FastConnectable = "false";
            Experimental = "true";
            # Enable Bluetooth ISO sockets so BlueZ's BAP plugin (LE Audio / LC3) can probe
            KernelExperimental = "6fbaf188-05e0-496a-9885-d6ddfdb4e03e";
          };
          Policy = {AutoEnable = "true";};
          LE = {EnableAdvMonInterleaveScan = 1;};
        };
      };
    };

    virtualisation = lib.mkIf isX86 {
      spiceUSBRedirection.enable = true;
      libvirtd = {
        enable = true;
        # lets libvirt find virtiofsd for <filesystem type='mount'> host shares
        qemu.vhostUserPackages = [pkgs.virtiofsd];
      };
    };

    programs = {
      seahorse.enable = true;
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
      pathsToLink = ["/share/xdg-desktop-portal" "/share/applications"];
      etc."strongswan.conf" = {
        enable = true;
        user = "root";
        group = "root";
        mode = "0644";
        text = "";
      };
      systemPackages = with pkgs; [
        bibata-cursors
        (runCommandLocal "bibata-cursor-default-theme" {} ''
          mkdir -p $out/share/icons
          ln -s ${bibata-cursors}/share/icons/Bibata-Modern-Ice $out/share/icons/default
        '')
        qemu
        quickemu
      ];
    };
  };
}
