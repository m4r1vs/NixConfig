{pkgs, ...}: {
  xdg-open-yt = {player ? "${pkgs.mpv}/bin/mpv"}:
    pkgs.writeShellScript "xdg-open-yt"
    ''
      url="$1"
      if echo "$url" | grep -q "youtube.com/watch\|youtu.be"; then
        ${player} --wayland-app-id=mpv-youtube --ytdl-format="bestvideo[height<=?1080]+bestaudio/best" "$url" &>/dev/null &
      else
        ${pkgs.brave}/bin/brave --new-window "$url"
      fi
    '';
}
