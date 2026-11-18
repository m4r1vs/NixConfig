{
  pkgs,
  helpers,
  scripts,
  ...
}: {
  copy-local-ip = helpers.mkScript {
    name = "copy-local-ip";
    runtimeInputs = [pkgs.iproute2 pkgs.gawk];
    text = ''
      # Source address of the default route, i.e. the IP of the active interface
      IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }' || true)"

      if [ -z "$IP" ]; then
        ${scripts.nixos-notify} -u low -e -t 3000 -h string:synchronous:copy-local-ip "No local IP" "Not connected to a network"
        exit 1
      fi

      printf '%s' "$IP" | ${helpers.clipboard.copy}
      ${helpers.playSound "clipboard"}
      ${scripts.nixos-notify} -u low -e -t 10000 -h string:synchronous:copy-local-ip "Copied IP:" "$IP"
    '';
  };
}
