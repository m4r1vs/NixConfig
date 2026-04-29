{
  pkgs,
  lib,
  config,
  scripts,
  ...
}: {
  rofi-calculator =
    pkgs.writeShellScript "rofi-calculator"
    # bash
    ''
      if [ ! -z "$@" ]; then
        # input=$(echo "$@" | sed 's/[[:space:]]*//g')
        input=$(echo "$@")

        SKIP_WOLFRAM=0

        if [ "$input" == "Copied!" ] || [ "$input" == "Goodbye" ]; then
          exit 1
        fi

        if [ $(tr -dc ' ' <<< "$input" | wc -c) -gt 0 ]; then

          first_word=$(echo "$input" | head -n1 | cut -d " " -f1)

          if [ "$first_word" == "󰆏" ]; then
            echo -n $input | sed 's/󰆏 //' | wl-copy > /dev/null
            ${scripts.nixos-notify} -u low -e -t 2000 "Copied Result"
            ${lib.optionalString (config.configured.system-sounds.enable && config.configured.system-sounds.clipboard.enable) "${pkgs.mpv}/bin/mpv --no-video --volume=80 ${config.configured.system-sounds.clipboard.soundFile} &"}
            exit 0
          fi

          if [ "$first_word" == "" ]; then
            to_be_typed=$(echo -n $input | sed 's/ //')
            coproc (sleep 0.01 && ${pkgs.wtype}/bin/wtype $to_be_typed > /dev/null 2>&1)
            exit 0
          fi

          if [ "$first_word" == "" ]; then
            echo "󰈆 Exit"
            to_be_typed=$(echo -n $input | sed 's/ //')
            ${pkgs.wtype}/bin/wtype $to_be_typed
            exit 0
          fi

          if [ "$first_word" == "How" ] || [ "$first_word" == "paste" ] || [ "$first_word" == "Paste" ] || [ "$first_word" == "." ]; then
            SKIP_WOLFRAM=1
          fi
        fi

        APPID="5H4A34-8PTG87GH54"

        RESPONSE='"Wolfram|Alpha did not understand your input"'

        if [ $SKIP_WOLFRAM -eq 0 ]; then
          QUERY=$(${pkgs.jq}/bin/jq -sRr @uri <<< "$*")
          RESPONSE=$(curl -s "https://api.wolframalpha.com/v1/result?appid=$APPID&units=metric&i=$QUERY")
        fi

        if [ "$RESPONSE" == '"No short answer available"' ]; then
          ${scripts.nixos-notify} -u low -e -t 2000 "There is no short answer. I'm opening the website for you..."
          coproc (xdg-open "https://wolframalpha.com/input?i=$*" > /dev/null 2>&1)
          ${pkgs.psmisc}/bin/killall rofi
          exit 0
        elif [ "$RESPONSE" == '"Wolfram|Alpha did not understand your input"' ]; then
          ${scripts.nixos-notify} -u low -e -t 2000 "Wait, let me query OpenAI..."
          ${pkgs.psmisc}/bin/killall rofi
          # GPT_RESPONSE=$(/home/mn/.local/share/mise/installs/bun/latest/bin/bun run /home/mn/code/personal-stuff/totoro/index.ts "$*")
          # dunstify -h string:x-dunst-stack-tag:totoro-assistant -a Totoro -t 0 "$GPT_RESPONSE"
          coproc (${pkgs.xdg-utils}/bin/xdg-open "https://chatgpt.com/?q=$*" > /dev/null 2>&1)
          exit 0
        else
          echo "󰆏 $RESPONSE"
          echo " $RESPONSE"
          echo " $RESPONSE"
        fi
      fi
    '';
}
