{
  scripts,
  helpers,
  ...
}: {
  open-linear-ticket = helpers.mkScript {
    name = "open-linear-ticket";
    text = ''
      clipboard="$(${helpers.clipboard.paste} 2>/dev/null || true)"

      if [[ -n "$clipboard" && "$clipboard" =~ ^[^[:space:]]+$ ]]; then
        ${helpers.openUrl} "https://linear.app/meetovo/issue/$clipboard"
        ${scripts.nixos-notify} "Opening $clipboard in Linear"
      else
        ${scripts.nixos-notify} "Not a Ticket: $clipboard"
      fi
    '';
  };
}
