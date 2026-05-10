{pkgs, ...}: {
  waybar-github =
    pkgs.writeShellScript "waybar-github"
    ''
      # Fetch notifications using gh CLI
      # Use --cache to avoid hitting rate limits too hard
      notifications=$( ${pkgs.gh}/bin/gh api notifications --cache 1m 2>/dev/null )

      if [ $? -ne 0 ]; then
        # If gh fails (e.g. not logged in), output nothing
        echo '{"text": " ", "tooltip": "Not logged into GitHub", "class": "error"}'
        exit 0
      fi

      count=$(echo "$notifications" | ${pkgs.jq}/bin/jq 'length')

      if [ "$count" -gt 0 ]; then
        echo "{\"text\": \" $count\", \"tooltip\": \"$count unread notifications\", \"class\": \"unread\"}"
      else
        echo '{"text": " 0", "tooltip": "No unread notifications", "class": "read"}'
      fi
    '';
}
