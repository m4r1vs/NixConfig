{
  systemArgs,
  lib,
  osConfig,
  ...
}: let
  isDesktop = osConfig.configured.desktop.enable;
  isWindows = osConfig ? wsl && osConfig.wsl.enable;
in {
  imports = [
    ./modules
    ./packages.nix
  ];

  home = {
    username = systemArgs.username;
    homeDirectory = "/home/${systemArgs.username}";
    sessionVariables =
      if isDesktop
      then {
        ELECTRON_OZONE_PLATFORM_HINT = "auto";
        NIXOS_OZONE_WL = "1";
      }
      else {};
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
      ghostty.enable = isDesktop || isWindows;
      git.enable = true;
      lazygit.enable = true;
      mpv.enable = true;
      neovim.enable = true;
      newsboat.enable = true;
      rofi.enable = isDesktop;
      spotify-player.enable = true;
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
  };

  fonts.fontconfig.enable = isDesktop;
}
