{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.swayimg;
in {
  options.programs.configured.swayimg = {
    enable = mkEnableOption "swayimg image viewer";
  };
  config = mkIf cfg.enable {
    programs.swayimg = {
      enable = true;
      package = pkgs.swayimg;
    };
    xdg.configFile."swayimg/init.lua".text =
      #lua
      ''
        swayimg.text.size = 16
        swayimg.text.color = 0xaaffffff
        swayimg.viewer.default_scale = "optimal"

        swayimg.overlay = true

        -- Opening a single file also lists its siblings, so j/k walk the directory.
        swayimg.imagelist.adjacent = true

        -- Vim-like binds on top of the defaults (arrows, PgUp/PgDn, ... keep working).
        -- Shifted letters must be spelled "Shift+g": swayimg lowercases the keysym
        -- and matches Shift separately, so a bare "G" would bind plain g.
        local function quit()
          swayimg.exit(0)
        end

        for _, mode in ipairs({swayimg.viewer, swayimg.slideshow}) do
          local function open(dir)
            return function()
              mode.open(dir)
            end
          end

          -- Pan by a tenth of the window, like the arrow keys.
          local function pan(dx, dy)
            return function()
              local wnd = swayimg.get_window_size()
              local pos = mode.get_position()
              mode.set_abs_position(
                pos.x + dx * math.floor(wnd.width / 10),
                pos.y + dy * math.floor(wnd.height / 10)
              )
            end
          end

          mode.on_key("q", quit)
          mode.on_key({"j", "l"}, open("next"))
          mode.on_key({"k", "h"}, open("prev"))
          mode.on_key("g", open("first"))
          mode.on_key("Shift+g", open("last"))
          mode.on_key("Shift+h", pan(1, 0))
          mode.on_key("Shift+l", pan(-1, 0))
          mode.on_key("Shift+k", pan(0, 1))
          mode.on_key("Shift+j", pan(0, -1))
        end

        local function pick(dir)
          return function()
            swayimg.gallery.select(dir)
          end
        end

        swayimg.gallery.on_key("q", quit)
        swayimg.gallery.on_key("h", pick("left"))
        swayimg.gallery.on_key("j", pick("down"))
        swayimg.gallery.on_key("k", pick("up"))
        swayimg.gallery.on_key("l", pick("right"))
        swayimg.gallery.on_key("g", pick("first"))
        swayimg.gallery.on_key("Shift+g", pick("last"))
        swayimg.gallery.on_key("Ctrl+d", pick("pgdown"))
        swayimg.gallery.on_key("Ctrl+u", pick("pgup"))
      '';
  };
}
