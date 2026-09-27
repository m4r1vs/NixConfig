{
  systemArgs,
  lib,
  osConfig,
  scripts,
  host,
  ...
}: {
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
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
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
      brave.enable = host.isDesktop;
      claude-code.enable = host.isDev;
      direnv.enable = true;
      docker-darwin.enable = host.isDarwin;
      fastfetch.enable = true;
      fzf.enable = true;
      ghostty.enable = host.isGraphical || host.isWSL;
      git.enable = true;
      helium.enable = host.isDesktop;
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
      rofi.enable = host.isDesktop;
      spotify-player.enable = host.isGraphical || host.isWSL;
      ssh.enable = true;
      swappy.enable = host.isDesktop;
      swayimg.enable = host.isWayland;
      tmux.enable = true;
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
