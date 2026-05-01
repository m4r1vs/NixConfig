{
  systemArgs,
  lib,
  osConfig,
  ...
}: let
  isDesktop = osConfig.configured ? desktop && osConfig.configured.desktop.enable;
  isWayland = osConfig.configured ? desktop && !osConfig.configured.i3.enable;
  isWSL = osConfig ? wsl && osConfig.wsl.enable;
  isDarwin = systemArgs.system == "aarch64-darwin";
  hasPowerProfiles = osConfig.services.power-profiles-daemon.enable or false;
in {
  imports = [
    ./modules
    ./packages.nix
  ];

  home = {
    username = systemArgs.username;
    sessionVariables = lib.mkIf isDesktop {
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      NIXOS_OZONE_WL = "1";
    };
    stateVersion = "24.05";
  };

  services = {
    configured = {
      darkman.enable = isDesktop;
      kdeconnect.enable = isDesktop;
      ollama.enable = false;
      auto-power-management.enable = hasPowerProfiles;
    };
    blueman-applet.enable = isDesktop && osConfig.services.blueman.enable;
    mpris-proxy.enable = isDesktop;
    network-manager-applet.enable = isDesktop;
    polkit-gnome.enable = isDesktop;
  };

  dconf.settings = lib.mkIf isDesktop {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };

  programs = {
    configured = {
      bat.enable = true;
      brave.enable = isDesktop;
      direnv.enable = true;
      docker-darwin.enable = isDarwin;
      fastfetch.enable = true;
      fzf.enable = true;
      gemini-cli.enable = true;
      ghostty.enable = isDesktop || isWSL || isDarwin;
      git.enable = true;
      lazygit.enable = true;
      mpv.enable = isDesktop || isDarwin;
      neovim.enable = true;
      newsboat.enable = isDesktop || isDarwin;
      oh-my-posh.enable = true;
      opencode.enable = true;
      rofi.enable = isDesktop;
      spotify-player.enable = isDesktop || isWSL || isDarwin;
      ssh.enable = true;
      swayimg.enable = isWayland;
      swappy.enable = isDesktop;
      tmux.enable = true;
      yazi.enable = true;
      zsh.enable = true;
    };
    home-manager.enable = true;
    k9s.enable = true;
    obs-studio.enable = isDesktop;
    zoxide.enable = true;
  };

  configured = {
    gtk.enable = isDesktop;
    qt.enable = isDesktop;
    xdg.enable = isDesktop;
    hushlogin.enable = isDarwin;
  };

  fonts.fontconfig.enable = isDesktop;
}
