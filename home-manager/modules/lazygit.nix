{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.lazygit;
  hunkCfg = config.programs.configured.hunk;

  # Hunk's static pager mode cannot probe the terminal via OSC 11 in a captured PTY (TERM=dumb),
  # so it hardcodes themeMode=null and always defaults to dark mode when theme="auto".
  # This wrapper detects system light/dark mode and explicitly passes the matching theme.
  hunkPager = pkgs.writeShellScript "lazygit-hunk-pager" ''
    if [ "$(uname)" = "Darwin" ]; then
      if /usr/bin/defaults read -g AppleInterfaceStyle 2>/dev/null | grep -q "Dark"; then
        THEME="github-dark-default"
      else
        THEME="github-light-default"
      fi
    elif command -v darkman >/dev/null 2>&1 && [ -n "$(darkman get 2>/dev/null)" ]; then
      if [ "$(darkman get 2>/dev/null)" = "light" ]; then
        THEME="github-light-default"
      else
        THEME="github-dark-default"
      fi
    elif command -v dconf >/dev/null 2>&1; then
      if dconf read /org/gnome/desktop/interface/color-scheme 2>/dev/null | grep -q "prefer-light"; then
        THEME="github-light-default"
      else
        THEME="github-dark-default"
      fi
    else
      THEME="github-dark-default"
    fi

    exec hunk pager --transparent-bg --theme "$THEME" "$@"
  '';
in {
  options.programs.configured.lazygit = {
    enable = mkEnableOption "TUI Git Client";
  };
  config = mkIf cfg.enable {
    programs.lazygit = {
      enable = true;
      settings = {
        gui = {
          scrollHeight = 4;
        };
        keybinding = {
          universal = {
            scrollUpMain = "<c-y>";
            scrollDownMain = "<c-e>";
          };
        };
        git = mkIf (hunkCfg.enable or false) {
          # Compatible with lazygit <= 0.61.x
          pagers = [
            {
              pager = "${hunkPager}";
            }
            {
              pager = "${hunkPager} --mode split";
            }
            {
              pager = "";
            }
          ];
          # Compatible with lazygit >= 0.64.x
          diffRenderers = [
            {
              name = "hunk";
              command = "${hunkPager}";
            }
            {
              name = "hunk-split";
              command = "${hunkPager} --mode split";
            }
            {
              name = "git";
              type = "rawGit";
            }
          ];
        };
      };
    };
  };
}
