{
  pkgs,
  scripts,
  ...
}: {
  open-linear-ticket =
    pkgs.writeShellScript "open-linear-ticket"
    ''
      clipboard="$(${pkgs.wl-clipboard}/bin/wl-paste --no-newline)"

      if [[ -n "$clipboard" && "$clipboard" =~ ^[^[:space:]]+$ ]]; then
        ${pkgs.xdg-utils}/bin/xdg-open "https://linear.app/meetovo/issues/$clipboard"
        ${scripts.nixos-notify} "Opening $clipboard in Linear"
      else
        ${scripts.nixos-notify} "Not a Ticket: $clipboard"
      fi
    '';
}
