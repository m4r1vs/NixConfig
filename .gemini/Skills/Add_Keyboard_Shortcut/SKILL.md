---
name: add-keyboard-shortcut
description: Use this skill to add a keyboard shortcut/keybind to the user's computer
---

# Add keyboard shortcut

## 1. Find potential conflicts

Look in @home-manager/modules/hyprland.nix for potential existing keybinds conflicting with the new one.
If yes, ask the user what they want to do:

- Overwrite existing bind, or
- Use the bind (then the one bind triggers both actions), or
- Suggest similar unused keybind

Query the nixos mcp server for home-manager hyprland configuration.
Bind-specific documentation is available in docs/Hyprland-Binds.md

## 2. Determine if Script is neccessary

If the action requires more than a single command execution or the command is complex, write a script into @home-manager/scripts
The script template:

```nix
{
  pkgs,
  ...
}: {
  rebuild =
    pkgs.writeShellScript "[ACTION-NAME]"
    ''
      echo "Hello World"
    ''
}
```

If the action is simple (or can be done without exec), continue without a script.

If the action is probably best done by hyprland itself, look at docs/Hyprland-Dispatchers.md for a list of hyprland dispatchers.

## 3. Implement keybind

Now edit @home-manager/modules/hyprland.nix to add the keybind based on the users inputs. Remember to always add a description.

## 4. Rebuild

Run the `rebuild` command (yes, simply `rebuild` as that is our custom script for rebuilding the nixos config).
