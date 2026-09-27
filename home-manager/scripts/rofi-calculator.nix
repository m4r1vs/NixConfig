{
  pkgs,
  helpers,
  scripts,
  ...
}: {
  rofi-calculator =
    pkgs.writeShellScript "rofi-calculator"
    # bash
    ''
      if [ -n "''${1-}" ]; then
        input="$*"

        SKIP_WOLFRAM=0

        if [ "$input" == "Copied!" ] || [ "$input" == "Goodbye" ]; then
          exit 1
        fi

        if [[ "$input" == *" "* ]]; then

          first_word=$(echo "$input" | head -n1 | cut -d " " -f1)

          if [ "$first_word" == "󰆏" ]; then
            printf '%s' "''${input#󰆏 }" | ${helpers.clipboard.copy} > /dev/null
            ${scripts.nixos-notify} -u low -e -t 2000 "Copied Result"
            ${helpers.playSound "clipboard"}
            exit 0
          fi

          if [ "$first_word" == "" ]; then
            to_be_typed="''${input#* }"
            coproc (sleep 0.01 && ${pkgs.wtype}/bin/wtype -- "$to_be_typed" > /dev/null 2>&1)
            exit 0
          fi

          if [ "$first_word" == "" ]; then
            echo "󰈆 Exit"
            to_be_typed="''${input#* }"
            ${pkgs.wtype}/bin/wtype -- "$to_be_typed"
            exit 0
          fi

          if [ "$first_word" == "How" ] || [ "$first_word" == "paste" ] || [ "$first_word" == "Paste" ] || [ "$first_word" == "." ]; then
            SKIP_WOLFRAM=1
          fi
        fi

        APPID="5H4A34-8PTG87GH54"

        RESPONSE='"Wolfram|Alpha did not understand your input"'

        QUERY=$(${pkgs.jq}/bin/jq -rn --arg q "$input" '$q|@uri')

        if [ "$SKIP_WOLFRAM" -eq 0 ]; then
          RESPONSE=$(${pkgs.curl}/bin/curl -s --connect-timeout 3 --max-time 6 "https://api.wolframalpha.com/v1/result?appid=$APPID&units=metric&i=$QUERY")
        fi

        # The API answers in plain text, so match with and without quotes
        if [[ "$RESPONSE" == *"No short answer available"* ]]; then
          ${scripts.nixos-notify} -u low -e -t 2000 "There is no short answer. I'm opening the website for you..."
          coproc (${pkgs.xdg-utils}/bin/xdg-open "https://wolframalpha.com/input?i=$QUERY" > /dev/null 2>&1)
          ${pkgs.psmisc}/bin/killall rofi || true
          exit 0
        elif [[ "$RESPONSE" == *"Wolfram|Alpha did not understand your input"* ]]; then
          ${scripts.nixos-notify} -u low -e -t 2000 "Wait, let me query OpenAI..."
          ${pkgs.psmisc}/bin/killall rofi || true
          # GPT_RESPONSE=$(/home/mn/.local/share/mise/installs/bun/latest/bin/bun run /home/mn/code/personal-stuff/totoro/index.ts "$*")
          # dunstify -h string:x-dunst-stack-tag:totoro-assistant -a Totoro -t 0 "$GPT_RESPONSE"
          coproc (${pkgs.xdg-utils}/bin/xdg-open "https://chatgpt.com/?q=$QUERY" > /dev/null 2>&1)
          exit 0
        else
          echo "󰆏 $RESPONSE"
          echo " $RESPONSE"
          echo " $RESPONSE"
        fi
      fi
    '';
}
