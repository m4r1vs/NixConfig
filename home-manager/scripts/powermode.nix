{
  pkgs,
  scripts,
  ...
}: {
  powermode = pkgs.writeShellScript "powermode" ''
    case "$1" in
    performance)
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance
      ${scripts.nixos-notify} -u low -e -h string:synchronous:powermode-changed "Power Mode: Performance" "Max performance enabled"
      ;;
    auto)
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
      ${scripts.nixos-notify} -u low -e -h string:synchronous:powermode-changed "Power Mode: Auto" "Balanced power and performance"
      ;;
    light)
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver
      ${scripts.nixos-notify} -u low -e -h string:synchronous:powermode-changed "Power Mode: Light" "Maximum power saving"
      ;;
    query)
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl get
      ;;
    *)
      echo "Usage: powermode {performance|auto|light|query}"
      echo "Current mode: $(${pkgs.power-profiles-daemon}/bin/powerprofilesctl get)"
      exit 1
      ;;
    esac
  '';
}
