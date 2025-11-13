{
  lib,
  config,
  pkgs,
  osConfig,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.yazi;
  isDesktop = osConfig.configured ? desktop && osConfig.configured.desktop.enable;
  isDarwin = systemArgs.system == "aarch64-darwin";
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
        mgr.prepend_keymap =
          [
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
            {
              on = "<C-z>";
              run = "plugin zoxide";
              desc = "Open Zoxide";
            }
          ]
          ++ (optionals isDesktop [
            {
              on = "p";
              run = "plugin ucp paste";
              desc = "Paste";
            }
            {
              on = "y";
              run = "plugin ucp copy";
              desc = "Copy";
            }
          ])
          ++ (optionals isDarwin [
            {
              on = "Y";
              run = ["yank" "plugin clippy"];
              desc = "Yank to System Clipboard";
            }
          ]);
      };
      settings = {
        tasks = {
          image_alloc = 0;
          image_bound = [20000 20000]; # roughly 200 Megapixel
        };
        preview = {
          max_width = 1200;
          max_height = 1200;
          image_quality = 60;
        };
        opener = {
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
      plugins =
        {
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
        }
        // (optionalAttrs isDesktop {
          ucp = pkgs.stdenv.mkDerivation {
            name = "yazi-ucp-plugin";
            src = pkgs.fetchFromGitHub {
              owner = "simla33";
              repo = "ucp.yazi";
              sha256 = "sha256-eSc3I2I4PZLVy7X/4SK5YjEOCx0/WoZAV/hzs0La0nU=";
              rev = "58fbaa512f52b7e26e5a54dc68b435b11140ced9";
            };
            installPhase = ''
              runHook preInstall
              mkdir $out
              mv main.lua $out/
              runHook postInstall
            '';
          };
        })
        // (optionalAttrs isDarwin {
          clippy = pkgs.stdenv.mkDerivation {
            name = "yazi-clippy-plugin";
            src = pkgs.fetchFromGitHub {
              owner = "gallardo994";
              repo = "clippy.yazi";
              sha256 = "sha256-oB9DkNWvUDbSAPnxtv56frlWWYz5vtu2BJVvWH/Uags=";
              rev = "8ce55413976ebd1922dbc4fc27ced9776823df54";
            };
            installPhase = ''
              runHook preInstall
              mkdir $out
              mv main.lua $out/
              runHook postInstall
            '';
          };
        });
    };
  };
}
