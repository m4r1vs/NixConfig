{
  pkgs,
  lib,
  helpers,
  ...
}: {
  /*
  Exec target of nvim.desktop. xdg-open runs a desktop entry inside its own
  process, so when it is called from a terminal (yazi, a shell) nvim simply
  takes over that terminal. Without one (rofi, browser, notification) nvim
  gets a new terminal window.
  */
  nvim-in-terminal = {nvim ? "nvim"}:
    helpers.mkScript {
      name = "nvim-in-terminal";
      runtimeInputs = [pkgs.procps];
      text = ''
        # "+" in ps' STAT column: we are in the terminal's foreground process
        # group, so nvim can take it over (a backgrounded caller could not)
        if [ -t 0 ] && [ -t 1 ] && [[ "$(ps -o stat= -p $$)" == *+* ]]; then
          exec ${nvim} "$@"
        fi

        exec ${lib.getExe pkgs.ghostty} -e ${nvim} "$@"
      '';
    };
}
