{
  pkgs,
  scripts,
  ...
}: {
  rofi-launch =
    pkgs.writeShellScript "rofi-launch"
    # bash
    ''
      case "$1" in
        ssh)
          ${pkgs.rofi}/bin/rofi -show ssh -theme-str "entry{placeholder:\"SSH into a Remote...\";}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 42;}window{padding: 38% 42%;}"
          ;;
        search)
          ${pkgs.rofi}/bin/rofi -theme-str "entry {placeholder: \"Launch a Program...\";padding: 10 10 0 4;}" -combi-modi search:${scripts.rofi-search},drun -show combi -drun-display-format "{name} [<span weight='regular' size='small'> {generic}</span>]"
          ;;
        emoji)
          ${pkgs.rofimoji}/bin/rofimoji --selector-args="-theme-str \"listview{dynamic:true;columns:12;layout:vertical;flow:horizontal;reverse:false;lines:8;}element-text{enabled:false;}element-icon{size:50px;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 24;}\"" --use-icons --typer wtype --clipboarder wl-copy --skin-tone neutral --selector rofi --max-recent 0 --action clipboard
          ;;
        calc)
          ${pkgs.rofi}/bin/rofi -modi calculator:${scripts.rofi-calculator} -show calculator -theme-str "entry {placeholder:\"Ask a Question...\";}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 42;}"
          ;;
        wallpaper)
          ${scripts.rofi-wallpaper}
          ;;
        power)
          ${pkgs.rofi}/bin/rofi -show power-menu -modi power-menu:${scripts.rofi-power-menu} -theme-str "entry {placeholder:\"Power Menu...\";}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 42;}window{padding: 38% 44%;}"
          ;;
        bluetooth)
          ${scripts.rofi-bluetooth}
          ;;
        cliphist)
          ${scripts.rofi-cliphist}
          ;;
        powermode)
          ${scripts.rofi-powermode}
          ;;
        obsidian)
          ${pkgs.rofi}/bin/rofi -modi obsidian:${scripts.rofi-obsidian} -show obsidian -theme-str "entry {placeholder:\"Open Obsidian Note...\";}element-icon{enabled:false;}icon-current-entry{enabled:false;}inputbar{padding: 0 0 0 42;}"
          ;;
        ocr)
          ${scripts.ocr-screenshot}
          ;;
        wifi)
          ${scripts.rofi-wifi}
          ;;
        translate)
          ${scripts.rofi-translate}
          ;;
        *)
          echo "Usage: $0 {ssh|search|emoji|calc|wallpaper|power|bluetooth|cliphist|powermode|obsidian|ocr|wifi|translate}"
          exit 1
          ;;
      esac
    '';
}
