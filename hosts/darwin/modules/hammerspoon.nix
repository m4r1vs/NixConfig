{
  lib,
  config,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.services.configured.hammerspoon;
in {
  options.services.configured.hammerspoon = {
    enable = mkEnableOption "Enable Hammerspoon";
  };

  config = mkIf cfg.enable {
    homebrew = {
      casks = [
        "hammerspoon"
      ];
    };
    home-manager.users.${systemArgs.username}.home.file.".hammerspoon/init.lua".text =
      # lua
      ''
        -- Use CTRL+X to move windows without left clicking them
        local mash = {"ctrl"}
        local triggerKey = "x"
        local dragging = false
        local dragTimer

        hs.hotkey.bind(mash, triggerKey,
          function()
            if dragging then return end
            dragging = true
            local pos = hs.mouse.absolutePosition()
            hs.eventtap.event.newMouseEvent(
              hs.eventtap.event.types.leftMouseDown,
              pos,
              {"ctrl", "cmd"}
            ):post()
            dragTimer = hs.timer.doEvery(0.01, function()
              hs.eventtap.event.newMouseEvent(
                hs.eventtap.event.types.leftMouseDragged,
                hs.mouse.absolutePosition(),
                {"ctrl", "cmd"}
              ):post()
            end)
          end,
          function()
            if not dragging then return end
            dragTimer:stop()
            hs.eventtap.event.newMouseEvent(
              hs.eventtap.event.types.leftMouseUp,
              hs.mouse.absolutePosition(),
              {"ctrl", "cmd"}
            ):post()
            dragging = false
          end
        )

        -- Make CMD-CTRL-K emulate CMD-K for Raycast, etc.
        local aerospaceDownMover
        local cmdKSimulator

        aerospaceDownMover = hs.hotkey.bind({"cmd"}, "k", function()
            hs.eventtap.keyStroke({"cmd", "shift"}, "u")
        end)

        cmdKSimulator = hs.hotkey.bind({"cmd", "ctrl"}, "k", function()
            cmdKSimulator:disable()
            aerospaceDownMover:disable()
            hs.eventtap.keyStroke({"cmd"}, "k")
            hs.timer.doAfter(0.1, function()
                cmdKSimulator:enable()
                aerospaceDownMover:enable()
            end)
        end)
      '';
  };
}
