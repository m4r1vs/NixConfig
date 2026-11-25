/*
Rofi `-modi` menu for hey-computer background tasks (`rofi-launch tasks`,
triggered on left-clicking the Waybar `󱚣` background-task icon).
Lets the user jump into `rofi-launch ask`, cancel running/queued background
tasks, or open completed background task answers in a floating viewer.
*/
{
  pkgs,
  lib,
  config,
  systemArgs,
  scripts,
  helpers,
  ...
}: let
  heyComputer = lib.getExe config.home-manager.users.${systemArgs.username}.programs.hey-computer.package;
in {
  rofi-hey-computer-tasks = helpers.mkScript {
    name = "rofi-hey-computer-tasks";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.jq
      pkgs.procps
    ];
    text =
      # bash
      ''
        set_placeholder() {
          local escaped
          escaped=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')
          printf '\000theme\037entry { placeholder: "%s"; }\n' "$escaped"
        }

        wake_watcher() {
          pkill -USR1 -f 'waybar-hey-computer watch' 2>/dev/null || true
        }

        render_menu() {
          printf '\000no-custom\037true\n'
          set_placeholder "Background Tasks..."
          printf '󰚩  Ask Computer…\000info\037ask\n'
          local speak_label="OFF"
          if speak_json=$(${heyComputer} speak status --json 2>/dev/null); then
            if [ "$(jq -r '.enabled // false' <<<"$speak_json" 2>/dev/null)" = "true" ]; then
              speak_label="ON"
            fi
          fi
          printf '󰕾  Spoken voice answers: %s  (Enter to toggle)\000info\037toggle-speak\n' "$speak_label"
          printf '󰧑  Distill recent memory & skills…\000info\037distill\n'

          local tasks_json
          if ! tasks_json=$(${heyComputer} tasks list --all --limit 12 --json 2>/dev/null); then
            return 0
          fi

          jq -r '
            def clean($s; $n):
              ($s // "" | gsub("[\\r\\n\\t]+"; " ") | sub("^ +"; "") | sub(" +$"; "")) as $t |
              if ($t | length) > $n then ($t[0:$n] + "…") else $t end;

            .[]
            | .id as $id
            | .status as $st
            | clean(.request; 56) as $req
            | clean(.error_message // .request; 56) as $err
            | if $st == "running" then
                "󱚣  [running] #\($id): \($req)  (Enter to cancel)\u0000info\u001fcancel:\($id)"
              elif $st == "queued" then
                "󰔟  [queued] #\($id): \($req)  (Enter to cancel)\u0000info\u001fcancel:\($id)"
              elif $st == "completed" then
                "󰄬  [done] #\($id): \($req)  (Enter to open)\u0000info\u001fopen:\($id)"
              elif $st == "suppressed" then
                "󰄬  [quiet] #\($id): \($req)\u0000info\u001fnoop"
              else
                "󰅚  [\($st)] #\($id): \($err)\u0000info\u001fnoop"
              end
          ' <<<"$tasks_json" 2>/dev/null || true
        }

        retv="''${ROFI_RETV:-0}"
        info="''${ROFI_INFO:-}"

        if [ "$retv" -eq 0 ]; then
          render_menu
          exit 0
        fi

        case "$info" in
        ask)
          nohup ${pkgs.rofi}/bin/rofi -modi ask:${scripts.rofi-ask} -show ask -theme-str 'entry {placeholder:"Ask Computer...";}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 42;}' </dev/null >/dev/null 2>&1 &
          exit 0
          ;;
        toggle-speak)
          ${heyComputer} speak toggle >/dev/null 2>&1 || true
          wake_watcher
          render_menu
          exit 0
          ;;
        distill)
          nohup ${heyComputer} distill </dev/null >/dev/null 2>&1 &
          exit 0
          ;;
        cancel:*)
          task_id="''${info#cancel:}"
          ${heyComputer} tasks cancel "$task_id" >/dev/null 2>&1 || true
          wake_watcher
          render_menu
          exit 0
          ;;
        open:*)
          task_id="''${info#open:}"
          nohup ${heyComputer} tasks open "$task_id" </dev/null >/dev/null 2>&1 &
          exit 0
          ;;
        *)
          exit 0
          ;;
        esac
      '';
  };
}
