{systemArgs, ...}: {
  imports = [
    ./disks.nix
    ./hardware-configuration.nix
    ./speaker-eq.nix
  ];

  configured = {
    nvidia.enable = false;
    laptop.enable = true;
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
    # Read with read-tpm-unlock-values.sh on 2026-11-21 (TPM_HARDENINGS.md)
    tpmUnlock = {
      volumeKeyId = "b56faa02df4bf493c765b812cf899c19b28aaab916d89dc9ef03e27abb770712";
      resumeOffset = 533760;
    };
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
    # Uniwill BIOS/EC updates come via the TUXEDO portal, not fwupd/LVFS
    tuxedo-drivers = {
      enable = true;
      # Cap charge at 80% ("stationary") to reduce battery wear
      settings.charging-profile = "stationary";
    };

    /*
    Radeon 890M with ROCm/OpenCL compute. No early KMS: with amdgpu in the
    initrd, the kernel that boots to restore a hibernation image brings the
    GPU up first, and the restored kernel then finds its MES firmware busy
    (gfx_v11_0 resume fails with -110, the screen stays black or garbled)
    */
    amdgpu = {
      initrd.enable = false;
      opencl.enable = true;
    };
  };

  boot = {
    kernelParams = [
      "acpi.ec_no_wakeup=1"
      "amdgpu.gpu_recovery=1"
      /*
      DC_DISABLE_REPLAY: no Panel Replay on the internal panel. After an
      s2idle resume its state changes time out (dmub_replay_enable WARN in
      dmesg), the suspected cause of the panel stuttering until reboot
      */
      "amdgpu.dcdebugmask=0x400"
    ];
  };

  systemd = {
    sleep.settings.Sleep.HibernateMode = "shutdown";

    /*
    polkit runs its PAM helper as a sandboxed unit whose private /dev has
    no camera, so howdy fails and polkit prompts (1Password unlock) fall
    back to the password. Expose the real /dev, allow only the standard
    pseudo devices plus V4L; the rest of upstream's hardening stays.
    */
    services = {
      "polkit-agent-helper@".serviceConfig = {
        PrivateDevices = false;
        DevicePolicy = "closed";
        DeviceAllow = ["char-video4linux rw"];
      };
    };
  };

  services = {
    /*
    Face unlock via the internal IR camera
    */
    howdy = {
      enable = true;
      settings.video.device_path = "/dev/v4l/by-path/pci-0000:65:00.4-usb-0:1:1.2-video-index0";
    };

    /*
    Work VPN for internal services. The daemon starts on boot; log in once
    with `netbird up` (the wrapped CLI already points at our management
    server), the peer config then persists in /var/lib/netbird. Its split DNS
    needs systemd-resolved, which desktop.nix turns on.
    */
    netbird = {
      enable = true;
      ui.enable = false;
      clients.default.environment.NB_MANAGEMENT_URL = "https://netbird.meetovo.dev";
    };

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

    # Friendly names instead of "Ryzen HD Audio Controller Analog Stereo" / "Radeon High Definition
    # Audio Controller Digital Stereo (HDMI 2)". The analog sink serves both speakers and the 3.5mm jack.
    pipewire.wireplumber.extraConfig."51-builtin-audio-names" = {
      "monitor.alsa.rules" = [
        {
          matches = [{"node.name" = "alsa_output.pci-0000_65_00.6.analog-stereo";}];
          actions.update-props = {
            "node.description" = "Built-in Audio";
            "node.nick" = "Built-in Audio";
          };
        }
        {
          # Any profile of the Radeon HDMI/DP audio controller (hdmi-stereo, -extra1, -extra2, surround, ...)
          matches = [{"node.name" = "~alsa_output.pci-0000_65_00.1.*";}];
          actions.update-props = {
            "node.description" = "Display Audio";
            "node.nick" = "Display Audio";
          };
        }
        {
          matches = [{"node.name" = "alsa_input.pci-0000_65_00.6.analog-stereo";}];
          actions.update-props = {
            "node.description" = "Built-in Microphone";
            "node.nick" = "Built-in Microphone";
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

  age.secrets = let
    userSecret = file: {
      inherit file;
      owner = systemArgs.username;
      group = "users";
      mode = "0400";
    };
  in {
    hey-computer-memory = userSecret ../../secrets/hey-computer-memory.age;
    hey-computer-notification-senders = userSecret ../../secrets/hey-computer-notification-senders.age;
    hey-computer-whatsapp-allow = userSecret ../../secrets/hey-computer-whatsapp-allow.age;
    hey-computer-signal-allow = userSecret ../../secrets/hey-computer-signal-allow.age;
    hey-computer-signal-account = userSecret ../../secrets/hey-computer-signal-account.age;
    google-workspace-client-secret = userSecret ../../secrets/google-workspace-client-secret.age;
    slack-mcp-xoxc = userSecret ../../secrets/slack-mcp-xoxc.age;
    slack-mcp-xoxd = userSecret ../../secrets/slack-mcp-xoxd.age;
  };

  system = {
    nixos.label = systemArgs.hostname + ".meetovo.de";
  };
}
