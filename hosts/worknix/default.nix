{systemArgs, ...}: {
  imports = [
    ./disks.nix
    ./hardware-configuration.nix
  ];

  configured = {
    nvidia.enable = false;
    desktop = {
      enable = true;
      windowManagers = {
        hyprland.enable = true;
        i3.enable = false;
        gamescope.enable = false;
      };
    };
    limine = {
      memtest = true;
      secureboot = true;
      resolution = "2880x1800";
    };
    system-sounds.enable = true;
    /*
    Ryzen AI 9 HX 370 NPU. The server runs whisper-large-v3-turbo, which is
    what npu-dictate (SUPER+v, hold to talk) transcribes against.
    */
    npu = {
      enable = true;
      server.enable = true;
    };
  };

  /*
  Local CA of the meetovo-backend dev proxy (`dev trust`), so curl and other
  tools trust https://<instance>.localhost. A copy of
  ~/.local/state/meetovo-dev/data/caddy/pki/authorities/local/root.crt; replace
  it when that state directory is recreated (the proxy then makes a new CA).
  */
  security.pki.certificateFiles = [./meetovo-dev-ca.crt];

  hardware = {
    enableRedistributableFirmware = true;
    wirelessRegulatoryDatabase = true;
    tuxedo-drivers = {
      enable = true;
      # Cap charge at 80% ("stationary") to reduce battery wear
      settings.charging-profile = "stationary";
    };

    /*
    Radeon 890M: early KMS so plymouth starts without a mode switch,
    plus ROCm/OpenCL compute
    */
    amdgpu = {
      initrd.enable = true;
      opencl.enable = true;
    };
  };

  boot = {
    kernelModules = ["tcp_bbr"];
    extraModprobeConfig = ''
      # Unlock 6 GHz Wi-Fi 6E channels on MT7922 in Germany
      options cfg80211 ieee80211_regdom=DE
    '';
    kernelParams = [
      "acpi.ec_no_wakeup=1"
      "amdgpu.gpu_recovery=1"
      /*
      DC_DISABLE_REPLAY: no Panel Replay on the internal panel. After an
      s2idle resume its state changes time out (dmub_replay_enable WARN in
      dmesg), the suspected cause of the panel stuttering until reboot
      */
      "amdgpu.dcdebugmask=0x400"
      # Compress swapped pages in RAM before hitting the 110 TBW QLC swapfile
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.max_pool_percent=20"
      "zswap.shrinker_enabled=0"
      # Stop periodic NMI watchdog interrupts and free a PMU counter on all threads
      "nmi_watchdog=0"
    ];
    kernel.sysctl = {
      # Cap dirty writeback buffers on 32 GiB RAM (overrides dirty_*_ratio defaults)
      "vm.dirty_background_bytes" = 67108864; # 64 MiB
      "vm.dirty_bytes" = 268435456; # 256 MiB
      # No multi-page swap readahead when backed by zswap/NVMe
      "vm.page-cluster" = 0;
      # TCP BBR congestion control with fq pacing
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    };
  };

  systemd = {
    sleep.settings.Sleep.HibernateMode = "shutdown";

    /*
    polkit runs its PAM helper as a sandboxed unit whose private /dev has
    no camera, so howdy fails and polkit prompts (1Password unlock) fall
    back to the password. Expose the real /dev, allow only the standard
    pseudo devices plus V4L; the rest of upstream's hardening stays.
    */
    services."polkit-agent-helper@".serviceConfig = {
      PrivateDevices = false;
      DevicePolicy = "closed";
      DeviceAllow = ["char-video4linux rw"];
    };

    coredump.settings.Coredump = {
      Storage = "external";
      Compress = "yes";
      MaxUse = "1G";
      ProcessSizeMax = "1G";
    };

    # Replaced by earlyoom, which reacts faster on Hyprland without per-app cgroup scopes
    oomd.enable = false;
  };

  services = {
    /*
    Dynamic CPU/Power modes
    */
    power-profiles-daemon.enable = true;

    /*
    Face unlock via the internal IR camera
    */
    howdy = {
      enable = true;
      settings.video.device_path = "/dev/v4l/by-path/pci-0000:65:00.4-usb-0:1:1.2-video-index0";
    };

    /*
    UEFI dbx and peripheral firmware via LVFS (Uniwill BIOS/EC updates come via
    the TUXEDO portal); limine signs fwupd.efi with our sbctl keys.
    */
    fwupd.enable = true;

    /*
    Split DNS via D-Bus for NetBird. With NixOS's default openresolv, NetBird
    takes exclusive ownership of /etc/resolv.conf and caches the original
    upstream nameservers at `netbird up` time, so switching networks leaves DNS
    pointing at the previous network's unreachable router until NetBird is
    cycled.
    */
    resolved.enable = true;

    /*
    Work VPN for internal services. The daemon starts on boot; log in once
    with `netbird up` (the wrapped CLI already points at our management
    server), the peer config then persists in /var/lib/netbird.
    */
    netbird = {
      enable = true;
      ui.enable = false;
      clients.default.environment.NB_MANAGEMENT_URL = "https://netbird.meetovo.dev";
    };

    /*
    B-Tree FS & SSD health monitoring (110 TBW QLC Crucial P310)
    */
    btrfs = {
      autoScrub = {
        enable = true;
        interval = "monthly";
        fileSystems = ["/"];
        limit = "250M";
      };
    };

    smartd = {
      enable = true;
      extraOptions = ["-i" "3600"];
      notifications.systembus-notify.enable = true;
    };

    earlyoom = {
      enable = true;
      enableNotifications = true;
    };

    udev.extraRules = ''
      # Use none scheduler on NVMe drives instead of linux-zen's kyber default
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
    '';

    hardware.bolt.enable = true;

    # Hide the IR camera from browsers/video calls while keeping /dev/video2 usable by Howdy.
    # Match on IR names rather than USB ID 2b7e:c906 (shared with the RGB webcam).
    pipewire.wireplumber.extraConfig."51-disable-ir-camera" = {
      "monitor.v4l2.rules" = [
        {
          matches = [
            {"device.description" = "~.*IR.*";}
            {"device.product.name" = "~.*IR.*";}
            {"api.v4l2.cap.card" = "~.*IR.*";}
          ];
          actions = {
            update-props = {
              "device.disabled" = true;
            };
          };
        }
      ];
    };
  };

  security = {
    /*
    Howdy authenticates sudo and polkit prompts (1Password unlock) on its
    own; every other PAM service keeps password-only auth instead of
    gaining a required second factor.
    */
    pam = {
      howdy.enable = false;
      services = let
        howdy = {
          howdy = {
            enable = true;
            control = "sufficient";
          };
        };
      in {
        sudo = howdy;
        polkit-1 = howdy;
      };
    };
  };

  home-manager.users.${systemArgs.username} = {
    programs.configured.hyprlock.scaling = 1.25;
  };

  system = {
    nixos.label = systemArgs.hostname + ".meetovo.de";
  };
}
