{
  systemArgs,
  lib,
  config,
  osConfig,
  scripts,
  host,
  ...
}: let
  usesBrowser = name: host.isDesktop && builtins.elem name config.programs.configured.browser.installed;
in {
  imports = [
    ./modules
    ./packages.nix
  ];

  home = {
    inherit (systemArgs) username;
    activation.initTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -f "$HOME/.theme/palette.json" ]; then
        run ${scripts.custom-wallpaper-theme} "default"
      fi
    '';
    sessionVariables = lib.mkIf host.isDesktop {
      NIXOS_OZONE_WL = "1";
    };
    stateVersion = "24.05";
  };

  services = {
    configured = {
      darkman.enable = host.isDesktop;
      kdeconnect.enable = host.isDesktop;
      auto-power-management.enable = host.hasPowerProfiles;
      auto-upgrade.enable = host.isDesktop;
    };
    blueman-applet.enable = host.isDesktop && osConfig.services.blueman.enable;
    mpris-proxy.enable = host.isDesktop;
    network-manager-applet.enable = host.isDesktop;
    polkit-gnome.enable = host.isDesktop;
  };

  dconf.settings = lib.mkIf host.isDesktop {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };

  programs = {
    configured = {
      antigravity-cli.enable = host.isDev;
      bat.enable = true;
      brave.enable = usesBrowser "brave";
      claude-code.enable = host.isDev;
      direnv.enable = true;
      docker-darwin.enable = host.isDarwin;
      fastfetch.enable = true;
      fzf.enable = true;
      galaxy-buds.enable = host.isDev && host.isDesktop && osConfig.services.blueman.enable;
      ghostty.enable = host.isGraphical || host.isWSL;
      git.enable = true;
      helium.enable = usesBrowser "helium";
      # Only where npu-dictate can trigger it ("Hey Computer, …"). Its agent runs
      # shell commands without confirmation, and can become root wherever this
      # account can without a password (hey-computer's README, "Permission model").
      hey-computer.enable = host.isDev && host.hasNpuServer && host.windowManager == "hyprland";
      hunk.enable = host.isDev;
      lazygit.enable = true;
      mcp.enable = host.isDev;
      mpv.enable = host.isGraphical;
      neovim = {
        enable = true;
        profile =
          if host.isDev
          then "full"
          else "base";
      };
      newsboat.enable = host.isGraphical;
      npu-dictate.enable = host.isDesktop && host.hasNpuServer;
      oh-my-posh.enable = true;
      opencode.enable = host.isDev;
      openhue.enable = host.isDesktop;
      rofi.enable = host.isGraphical;
      spotify-player.enable = host.isGraphical || host.isWSL;
      ssh.enable = true;
      swappy.enable = host.isDesktop;
      swayimg.enable = host.isWayland;
      tmux.enable = true;
      waybar.enable = lib.mkDefault host.isDarwin;
      yazi.enable = host.isDev;
      zsh.enable = true;
    };
    home-manager.enable = true;
    k9s.enable = host.isDev;
    obs-studio.enable = host.isDesktop;
    zoxide.enable = true;
  };

  configured = {
    gtk.enable = host.isDesktop;
    qt.enable = host.isDesktop;
    xdg.enable = host.isDesktop;
    hushlogin.enable = host.isDarwin;
  };

  fonts.fontconfig.enable = host.isDesktop;
}
