{
  systemArgs,
  lib,
  osConfig,
  ...
}: let
  isDesktop = osConfig.configured ? desktop && osConfig.configured.desktop.enable;
  isWSL = osConfig ? wsl && osConfig.wsl.enable;
  isDarwin = systemArgs.system == "aarch64-darwin";
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
    };
    blueman-applet.enable = isDesktop;
    mpris-proxy.enable = isDesktop;
    network-manager-applet.enable = isDesktop;
    polkit-gnome.enable = isDesktop;
    swww.enable = isDesktop;
  };

  dconf.settings = lib.mkIf isDesktop {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };

  programs = {
    configured = {
      brave.enable = isDesktop;
      direnv.enable = true;
      fzf.enable = true;
      ghostty.enable = isDesktop || isWSL || isDarwin;
      git.enable = true;
      lazygit.enable = true;
      mpv.enable = isDesktop || isDarwin;
      neovim.enable = true;
      newsboat.enable = isDesktop || isDarwin;
      rofi.enable = isDesktop;
      spotify-player.enable = isDesktop || isWSL || isDarwin;
      ssh.enable = true;
      swappy.enable = isDesktop;
      tmux.enable = true;
      waybar.enable = isDesktop;
      yazi.enable = true;
      zsh.enable = true;
    };
    bat.enable = true;
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
    raycast-scripts.enable = false;
  };

  fonts.fontconfig.enable = isDesktop;
}
