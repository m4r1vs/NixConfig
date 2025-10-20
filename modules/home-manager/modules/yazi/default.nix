{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.yazi;
in {
  options.programs.configured.yazi = {
    enable = mkEnableOption "Terminal File Manager";
  };
  config = mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      shellWrapperName = "y";
      enableZshIntegration = true;
      keymap = {
        mgr.prepend_keymap = [
          {
            run = ''shell 'printf "Mode Bits: "; read ans; chmod $ans "$@"' --block --confirm'';
            on = "=";
            desc = "chmod";
          }
          {
            run = "escape";
            on = ["<Esc>"];
          }
          {
            on = "l";
            run = "plugin smart-enter";
            desc = "Enter the child directory, or open the file";
          }
          {
            on = "T";
            run = "plugin toggle-pane max-preview";
            desc = "Maximize or restore the preview pane";
          }
          {
            on = "f";
            run = "plugin jump-to-char";
            desc = "Jump to char";
          }
        ];
      };
      settings = {
        opener = {
          gimp = [
            {
              run = "${pkgs.gimp-with-plugins}/bin/gimp \"$@\"";
              desc = "GIMP";
              block = true;
              for = "unix";
            }
          ];
          edit = [
            {
              run = "${config.programs.neovim.finalPackage}/bin/nvim \"$@\"";
              desc = "NeoVim";
              block = true;
              for = "unix";
            }
          ];
          open = [
            {
              run = "${pkgs.xdg-utils}/bin/xdg-open \"$@\"";
              desc = "xdg-open";
              block = true;
              for = "unix";
            }
          ];
          play = [
            {
              run = "${config.programs.mpv.finalPackage}/bin/mpv \"$@\"";
              block = true;
              for = "unix";
            }
          ];
        };
        open.prepend_rules = [
          {
            mime = "image/*";
            use = ["open" "gimp"];
          }
          {
            mime = "audio/*";
            use = ["play" "open"];
          }
          {
            mime = "video/*";
            use = ["play" "open"];
          }
          {
            mime = "text/*";
            use = ["edit"];
          }
        ];
        plugin.prepend_fetchers = [
          {
            id = "git";
            name = "*";
            run = "git";
          }
          {
            id = "git";
            name = "*/";
            run = "git";
          }
        ];
      };
      initLua = ./init.lua;
      flavors = {
        dark = pkgs.fetchFromGitHub {
          owner = "m4r1vs";
          repo = "dark.yazi";
          rev = "main";
          sha256 = "sha256-4yRYPoQ4PsnNRo+VzworhWrwNFrBYPHD1bu8agjsc/I=";
        };
        light = pkgs.fetchFromGitHub {
          owner = "m4r1vs";
          repo = "light.yazi";
          rev = "main";
          sha256 = "sha256-V6N1/RHcPus3ec2Hxit09/wwK0j69jIpE8jyg8qJ2ZE=";
        };
      };
      theme = {
        flavor = {
          dark = "dark";
          light = "light";
        };
        status = {
          separator_open = "";
          separator_close = "";
        };
      };
      plugins = {
        git = pkgs.stdenv.mkDerivation {
          name = "yazi-git-plugin";
          src = pkgs.fetchFromGitHub {
            owner = "yazi-rs";
            repo = "plugins";
            sha256 = "sha256-WF2b9t0VPGNP3QXgr/GMDFcSh5bsXC7KKd2ICL4WDHo=";
            rev = "d642bfb0822eb0c3c5c891ab0f4b6f897a2083cb";
          };
          installPhase = ''
            runHook preInstall
            mkdir $out
            mv git.yazi/*.lua $out/
            runHook postInstall
          '';
        };
        jump-to-char = pkgs.stdenv.mkDerivation {
          name = "yazi-jump-to-char-plugin";
          src = pkgs.fetchFromGitHub {
            owner = "yazi-rs";
            repo = "plugins";
            sha256 = "sha256-WF2b9t0VPGNP3QXgr/GMDFcSh5bsXC7KKd2ICL4WDHo=";
            rev = "d642bfb0822eb0c3c5c891ab0f4b6f897a2083cb";
          };
          installPhase = ''
            runHook preInstall
            mkdir $out
            mv jump-to-char.yazi/*.lua $out/
            runHook postInstall
          '';
        };
        smart-enter = pkgs.stdenv.mkDerivation {
          name = "yazi-smart-enter-plugin";
          src = pkgs.fetchFromGitHub {
            owner = "yazi-rs";
            repo = "plugins";
            sha256 = "sha256-WF2b9t0VPGNP3QXgr/GMDFcSh5bsXC7KKd2ICL4WDHo=";
            rev = "d642bfb0822eb0c3c5c891ab0f4b6f897a2083cb";
          };
          installPhase = ''
            runHook preInstall
            mkdir $out
            mv smart-enter.yazi/*.lua $out/
            runHook postInstall
          '';
        };
        toggle-pane = pkgs.stdenv.mkDerivation {
          name = "yazi-toggle-pane-plugin";
          src = pkgs.fetchFromGitHub {
            owner = "yazi-rs";
            repo = "plugins";
            sha256 = "sha256-WF2b9t0VPGNP3QXgr/GMDFcSh5bsXC7KKd2ICL4WDHo=";
            rev = "d642bfb0822eb0c3c5c891ab0f4b6f897a2083cb";
          };
          installPhase = ''
            runHook preInstall
            mkdir $out
            mv toggle-pane.yazi/*.lua $out/
            runHook postInstall
          '';
        };
      };
    };
  };
}
