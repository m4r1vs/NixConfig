{
  config,
  pkgs,
  systemArgs,
  ...
}: let
  browser = config.home-manager.users.${systemArgs.username}.programs.configured.browser.resolved.default;
in {
  xdg-open-yt = {player ? "${pkgs.mpv}/bin/mpv"}:
    pkgs.writeShellScript "xdg-open-yt"
    ''
      url="$1"
      if echo "$url" | grep -q "youtube.com/watch\|youtu.be"; then
        ${player} --wayland-app-id=mpv-youtube --ytdl-format="bestvideo[height<=?1080]+bestaudio/best" "$url" &>/dev/null &
      else
        ${browser.exe} --new-window "$url"
      fi
    '';
}
