---
name: add-keyboard-shortcut
description: Use this skill to add a keyboard shortcut/keybind to the user's computer
---

# Add keyboard shortcut

## 1. Find potential conflicts

Look in `home-manager/modules/hyprland.nix` for potential existing keybinds conflicting with the new one.
Compare modifiers as a set and key names case-insensitively: `"SUPER + SHIFT + G"` and `"SHIFT + SUPER + g"` are the same combination.
Also list what the running Hyprland has bound to the key (set `--arg key`), which includes binds the Nix file generates, such as the workspace loop:

```sh
hyprctl binds -j | jq -r --arg key g '.[] | select(.key | ascii_downcase == ($key | ascii_downcase)) | .modmask as $m | ([{SUPER: 64, SHIFT: 1, CTRL: 4, ALT: 8, CAPS: 2, MOD2: 16, MOD3: 32, MOD5: 128} | to_entries[] | select(($m / .value | floor) % 2 == 1) | .key] + [.key] | join(" + ")) + "\t" + .description'
```

It only shows this host's binds from the last rebuild, so it complements reading the Nix file rather than replacing it.
If there is a conflict, ask the user what they want to do:

- Overwrite existing bind, or
- Use the bind (then the one bind triggers both actions), or
- Suggest similar unused keybind

Query the nixos MCP server for home-manager hyprland configuration (e.g. `nix {"action":"search","source":"home-manager","query":"hyprland"}`).
For the key syntax, `hl.bind` options and the `hl.dsp.*` dispatchers with their arguments, read [docs/Hyprland-Lua-API.md](docs/Hyprland-Lua-API.md); the Hyprland stubs referenced by `~/.config/hypr/.luarc.json` are only good for object field names.

## 2. Determine if a script is necessary

If the action requires more than a single command execution or the command is complex, write a script into `home-manager/scripts/`.
The script template:

```nix
{
  pkgs,
  helpers,
  ...
}: {
  [action-name] = helpers.mkScript {
    name = "[action-name]";
    runtimeInputs = with pkgs; [];
    text = ''
      echo "Hello World"
    '';
  };
}
```

If the action is simple (or can be done without exec), continue without a script.

If the action is probably best done by hyprland itself, find the dispatcher in [docs/Hyprland-Lua-API.md](docs/Hyprland-Lua-API.md).

## 3. Implement keybind

Now edit `home-manager/modules/hyprland.nix` to add the keybind based on the user's inputs.
`home-manager/modules/hyprland.nix` uses `configType = "lua"`; binds go in `settings.bind` through the helpers in the `let` block at the top of the file (`bindd`, `bindde`, `binddle`, `binddrin`, `exec`, ...):

- Key combinations use `+` between modifiers and the key, with uppercase modifiers (`SUPER`, `SHIFT`, `CTRL`, `ALT`), e.g. `"SUPER + SHIFT + x"`.
- Dispatchers use `hl.dsp.*` Lua expressions (e.g. `(exec "${scripts.my-script}")`, `''hl.dsp.window.close()''`, `''hl.dsp.focus({ direction = "l" })''`) or a Lua function (`function() ... end`) defined as a helper in the `let` block, like `moveOrTile` and `toggleFakeFullscreen`; functions must run dispatchers through `hl.dispatch(...)`.
- Remember to always include a description.

## 4. Rebuild

Run the `rebuild` command (yes, simply `rebuild` as that is our custom script for rebuilding the nixos config).
Then check the result with `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua`, which prints `config ok` or the errors (load-time only: function bodies, selectors and many dispatcher argument values are only checked at keypress).
Do not rely on `hyprctl configerrors`: every `hyprctl dispatch` or `eval` clears its list.
