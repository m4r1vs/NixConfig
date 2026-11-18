{
  host,
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.yazi;
  inherit (host) isDarwin isDesktop;
  xdgOpen = "${pkgs.xdg-utils}/bin/xdg-open";
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
            {
              on = "<C-g>";
              run = "plugin vcs-files";
              desc = "Show Git file changes";
            }
            {
              on = "M";
              run = "plugin mount";
              desc = "Show mounted drives";
            }
          ]
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
        opener =
          {
            edit = [
              {
                run = "${config.programs.neovim.finalPackage}/bin/nvim \"$@\"";
                desc = "NeoVim";
                block = true;
                for = "unix";
              }
            ];
            /*
            The program is xdg-open's choice (xdg.mimeApps). Blocking keeps it
            a child of this terminal, which is what lets Hyprland swallow the
            terminal until the program exits. xdg-open takes a single file, so
            %s1 makes yazi run it once per selected file
            */
            open = [
              {
                run = "${xdgOpen} %s1";
                desc = "xdg-open";
                block = true;
                for = "unix";
              }
            ];
            play = [
              {
                run = "mpv \"$@\"";
                block = true;
                for = "unix";
              }
            ];
          }
          // optionalAttrs isDesktop {
            # A browser outlives the file: don't wait for it, and start it
            # outside this terminal's process tree so it can't swallow it
            browse = [
              {
                run = "${pkgs.util-linux}/bin/setsid -f ${xdgOpen} %s1";
                desc = "Browser";
                orphan = true;
                for = "linux";
              }
            ];
          };
        /*
        Everything not listed falls through to yazi's preset, which ends in
        "open" (xdg-open). Text stays with "edit": yazi sniffs the content,
        xdg-open goes by file name first and would send e.g. *.svelte to the
        browser. Both end up in nvim inside this terminal
        */
        open.prepend_rules =
          optionals isDesktop [
            {
              url = "*.{html,htm,xhtml}";
              use = ["browse" "edit" "reveal"];
            }
          ]
          ++ [
            {
              mime = "image/*";
              use = ["open"];
            }
            {
              mime = "{audio,video}/*";
              # mpv.desktop gives music a window too, "play" stays in the terminal
              use =
                if isDesktop
                then ["open" "play"]
                else ["play" "open"];
            }
            {
              mime = "text/*";
              use = ["edit"];
            }
          ];
        plugin.prepend_fetchers = [
          {
            id = "git";
            url = "*";
            run = "git";
            group = "git";
          }
          {
            id = "git";
            url = "*/";
            run = "git";
            group = "git";
          }
        ];
      };
      initLua = ./init.lua;
      flavors = {
        dark = inputs.dark-yazi;
        light = inputs.light-yazi;
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
          git = pkgs.yaziPlugins.git;
          jump-to-char = pkgs.yaziPlugins.jump-to-char;
          smart-enter = pkgs.yaziPlugins.smart-enter;
          toggle-pane = pkgs.yaziPlugins.toggle-pane;
          mount = pkgs.yaziPlugins.mount;
          vcs-files = pkgs.yaziPlugins.vcs-files;
        }
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
