/*
Stand-in for the hosts that consume this flake from their own repository (see
"Downstream hosts" in CLAUDE.md). It sets everything those hosts rely on, so
the eval-hosts check fails here when a change would break them.
*/
{
  lib,
  ownInputs,
  systemArgs,
  ...
}: {
  # Placeholder disks: enough to evaluate, never installed
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
    };
    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };
  };

  assertions = [
    {
      assertion = ownInputs ? upstream;
      message = "mkHost no longer passes extraArgs on to the modules.";
    }
  ];

  configured = {
    host.isDev = false;
    nvidia.enable = false;
    desktop = {
      enable = true;
      windowManagers = {
        hyprland.enable = true;
        i3.enable = true;
        gamescope.enable = true;
      };
    };
    i3.scaling = 2;
    limine = {
      memtest = true;
      secureboot = false;
    };
  };

  services.power-profiles-daemon.enable = true;

  programs = {
    _1password.enable = lib.mkForce false;
    _1password-gui.enable = lib.mkForce false;
  };

  home-manager.users.${systemArgs.username} = {
    programs.configured = {
      browser = {
        default = "helium";
        secondaryProfile = false;
      };
      hyprland = {
        # One app placed when it starts, one kept on its workspace by a rule
        startupApps = [
          {
            command = "true";
            workspace = "name:0";
          }
          {
            command = "true";
            workspace = 2;
            match.initial_class = "^(example)$";
          }
        ];
        umlautBinds = false;
        maxVolume = 150;
        powerMenuExit = true;
      };
      hyprlock.scaling = 2.0;
      yazi.enable = lib.mkForce true;
    };

    wayland.windowManager.hyprland.settings = {
      config.input.kb_layout = lib.mkForce "de,us";
      monitor = lib.mkForce [
        {
          output = "";
          mode = "highres";
          position = "auto";
          scale = 2;
        }
      ];
      bind = [
        {
          _args = [
            "SUPER + code:49"
            (lib.generators.mkLuaInline ''hl.dsp.focus({ workspace = "name:0" })'')
            {description = "Switch to workspace 0";}
          ];
        }
      ];
      workspace_rule = [
        {
          workspace = "name:0";
          persistent = true;
        }
      ];
      window_rule = lib.mkAfter [
        {
          match.initial_class = "^(md.obsidian.Obsidian)$";
          workspace = "name:0";
        }
      ];
      on = [
        {
          _args = [
            "hyprland.start"
            (lib.generators.mkLuaInline ''
              function()
                hl.exec_cmd("true")
              end'')
          ];
        }
      ];
    };

    services.configured.auto-upgrade.schedule = "weekly";

    programs.waybar.settings.mainBar."hyprland/workspaces".format = "{name}";

    xsession.windowManager.i3.config.keybindings."Mod4+asciicircum" = "workspace number 0";
  };
}
