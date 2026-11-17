# Hyprland Lua API for keybinds

Derived from the Hyprland **0.55.4** source. The bundled stubs (`share/hypr/stubs/hl.meta.lua`) type every
`hl.dsp.*` as `fun(...)`, so argument lists below come from the C++ code, not the stubs.

## `hl.bind(keys, action, opts?)`

`action` is a dispatcher (`hl.dsp.window.close()`) or a Lua function. Returns an `HL.Keybind`
(`:set_enabled(bool)`, `:is_enabled()`, `:remove()`). An error does not abort the config: it is recorded, so
`Hyprland --verify-config` reports it. An invalid key string, action or option combination skips that bind;
some other errors, such as a `description` that is neither a string nor a number, or (for most dispatchers) a
missing required field, are reported while the bind is still added.

Several binds on the same combination are all kept, and every matching one runs, in definition order.
Nothing overrides or warns.

### Key string

| Form | Meaning |
| --- | --- |
| `MOD + MOD + key` | Split on `+`, each part trimmed. Modifiers must come first ("Modifiers must come first in the list"). |
| Modifier names | Case-sensitive, see the table below. `super` is not a modifier: it is looked up as a key name and fails. |
| Key names | xkb keysym names, looked up case-insensitively. Where names differ only by case xkb returns the lower-case keysym, so `G` and `g` are the same key: `SUPER + SHIFT + G` and `SUPER + SHIFT + g` are two binds on one combination. Case never implies `SHIFT`. |
| Unknown names | Error. `Enter` suggests `Return`; a name containing a space suggests a missing `+`. Use keysym names for symbols (`plus`, `minus`, `slash`, `bracketright`). |
| `code:N` | Raw keycode `N`. Shown with an empty `key` in `hyprctl binds -j`. |
| `mouse:N` | Mouse button by button code, e.g. `mouse:272`. |
| `mouse_down`, `mouse_up` / `mouse_left`, `mouse_right` | Vertical / horizontal scroll wheel. |
| `switch:NAME`, `switch:on:NAME`, `switch:off:NAME` | Switch toggled / turned on / turned off (e.g. a lid switch). |
| `SUPER + a + k` | Chord: fires when `k` is pressed while `a` is held (and no other non-modifier key). Plain binds on the same modifiers still fire on their own key: `SUPER + a` when `a` goes down, `SUPER + k` together with the chord. |
| `catchall` | The whole string. Only allowed inside `hl.define_submap`. Matches keyboard keys pressed with no modifier held (any modifiers with `ignore_mods`), never mouse buttons, scroll or switches. It is not a fallback: when another bind in the submap matches the key, both run (unless an earlier `release` bind without `non_consuming`/`auto_consuming` matched it). |

`mouse*` and `switch:*` cannot be combined with another key. Modifiers must match exactly (bitmask equality)
unless `ignore_mods` is set.

| Modifier names | `modmask` bit |
| --- | --- |
| `SHIFT` | 1 |
| `CAPS` | 2 |
| `CTRL`, `CONTROL` | 4 |
| `ALT`, `MOD1` | 8 |
| `MOD2` | 16 |
| `MOD3` | 32 |
| `SUPER`, `WIN`, `LOGO`, `MOD4`, `META` | 64 |
| `MOD5` | 128 |

### Options

Booleans are read with Lua truthiness. The stubs' `HL.BindOptions` omits `auto_consuming`.

| Option | Legacy flag | Effect |
| --- | --- | --- |
| `description` (or `desc`) | `d` | Text shown by `hyprctl binds`; `description` wins if both are set. |
| `repeating` | `e` | Repeats while held, at the keyboard repeat rate. |
| `locked` | `l` | Also works while the session is locked. |
| `release` | `r` | Fires on key release. |
| `long_press` | `o` | Fires after the key is held for the keyboard repeat delay. |
| `non_consuming` | `n` | The key event is still passed to the focused window. |
| `auto_consuming` | `a` | Consumes the event only if the action succeeded. |
| `transparent` | `t` | Cannot be shadowed by other binds. |
| `ignore_mods` | `i` | Matches whatever modifiers are held. |
| `dont_inhibit` | `p` | Works even while a client inhibits shortcuts. |
| `submap_universal` | `u` | Active in every submap. |
| `click` | `c` | Implies `release`; fires only if the pointer stayed within `binds:drag_threshold`. |
| `drag` | `g` | Implies `release`; fires only if the pointer moved beyond `binds:drag_threshold`. |
| `device = { list = {...}, inclusive = true }` | `k` | Only for devices whose name or tag is in `list`; `inclusive = false` means all except those. |

Rejected combinations: `click` with `drag`; `repeating` with `release`, `long_press`, `click` or `drag`.

Legacy flags without an option: `s` (multi-key) is replaced by the chord syntax above. `m` (mouse) has none, and `hlBind`
never reads a `mouse` option, even though Hyprland's bundled example passes `{ mouse = true }`.
`hl.dsp.window.drag()` and `hl.dsp.window.resize()` start a mouse drag that lasts until the next key or
mouse-button event: Hyprland ends an active drag before matching any bind (`ensureMouseBindState`), so in
practice releasing the button, the key or a modifier ends it. Like `pass`, `global` and `send_shortcut`, they
also mark the bind release-pending, so it runs once more on release if the modifiers are still held: those
three use that run to deliver the release, and a Lua function that starts a drag runs a second time.

`hl.unbind(keys)` removes binds whose key string is equal after removing spaces and lower-casing;
`hl.unbind("all")` removes every bind.

## Dispatchers (`hl.dsp.*`)

Each call returns an `HL.Dispatcher`, or nothing if building fails. Building it (at config load for binds)
checks required arguments and fields (a missing field is reported, but most dispatchers are still built) and a
few values: `direction`, `into_group`, `into_or_create_group`, `fullscreen` `mode`/`action`, `fullscreen_state`
`action` and `send_key_state` `state`. A non-table where an optional table is expected is silently ignored
(`hl.dsp.window.close("class:foo")` closes the focused window), except by `hl.dsp.window.resize`, which
reports it and returns nothing. Everything else, such as selector strings, `out_of_group`, `alter_zorder`
modes, `corner`, `signal`, `send_shortcut` keys, submap names and `exec_cmd` rules, is checked (if at all)
only when the dispatcher runs, so `--verify-config` does not catch it.
Most take one table; positional arguments are noted. `window` is a window selector and defaults to the
focused window. Selector syntax is under [Selectors](#selectors).

Shared argument values:

| Argument | Accepted values |
| --- | --- |
| `direction` (and `into_group`, `into_or_create_group`, `out_of_group`) | `left`/`l`, `right`/`r`, `up`/`u`/`t`, `down`/`d`/`b` |
| `action` on toggles (`float`, `pseudo`, `pin`, `deny_from_group`, `group.lock`, `group.lock_active`, `dpms`) | `toggle` (default), `enable`/`on`, `disable`/`off`; anything else toggles |

### Top level

| Dispatcher | Notes | Replaces |
| --- | --- | --- |
| `hl.dsp.exec_cmd(cmd, rules?)` | `cmd` runs via `/bin/sh -c`; a leading `[...]` is parsed as exec rules. `rules`: table of window-rule effects for the spawned window (`floating` is accepted for `float`). | `exec` |
| `hl.dsp.exec_raw(cmd)` | Like `exec_cmd`, without rule parsing. | `execr` |
| `hl.dsp.focus({...})` | First key present wins: `direction`; `monitor`; `workspace` (+ `on_current_monitor = true`); `window`; `urgent_or_last = true`; `last = true`. | `movefocus`, `focusmonitor`, `workspace`, `focusworkspaceoncurrentmonitor`, `focuswindow`, `focuswindowbyclass`, `focusurgentorlast`, `focuscurrentorlast` |
| `hl.dsp.layout(msg)` | Layout message string, e.g. `"togglesplit"`. | `layoutmsg` |
| `hl.dsp.submap(name)` | Enter submap `name`. | `submap` |
| `hl.dsp.pass({ window })` | Send the triggering key or button to `window` (required). | `pass` |
| `hl.dsp.send_shortcut({ mods, key, window? })` | `mods`: string, e.g. `"SUPER SHIFT"` (names found anywhere, case-insensitive). `key`: keysym name, `code:N`, a number above 9 (keycode) or `mouse:N` (N ≥ 272). | `sendshortcut` |
| `hl.dsp.send_key_state({ mods, key, state, window? })` | As above; `state`: `"down"`, `"up"` or `"repeat"`. | `sendkeystate` |
| `hl.dsp.global(name)` | `"appid:name"` global shortcut. | `global` |
| `hl.dsp.event(data)` | Emits IPC event `custom>>data`. | `event` |
| `hl.dsp.dpms({ action?, monitor? })` | Without `monitor`, or when it matches no monitor at run time: all monitors. | `dpms` |
| `hl.dsp.force_idle(seconds)` | Number. | `forceidle` |
| `hl.dsp.force_renderer_reload()` | | `forcerendererreload` |
| `hl.dsp.exit()` | Quits Hyprland. | `exit` |
| `hl.dsp.no_op()` | Does nothing. | |

### Window (`hl.dsp.window.*`)

| Dispatcher | Notes | Replaces |
| --- | --- | --- |
| `close({ window? })` | Asks the window to close. | `killactive`, `closewindow` |
| `kill({ window? })` | Sends `SIGKILL` to its process. | `forcekillactive`, `killwindow` |
| `signal({ signal, window? })` | Signal number. | `signal`, `signalwindow` |
| `float({ action?, window? })` | Toggle action. | `togglefloating`, `setfloating`, `settiled` |
| `pseudo({ action?, window? })` | Toggle action. | `pseudo` |
| `pin({ action?, window? })` | Toggle action. | `pin` |
| `fullscreen({ mode?, action?, window? })` | `mode`: `"fullscreen"`/`"0"` (default) or `"maximized"`/`"1"`. `action`: `"toggle"` (default), `"set"`, `"unset"`. | `fullscreen` |
| `fullscreen_state({ internal, client, action?, window? })` | `internal`, `client`: 0 none, 1 maximized, 2 fullscreen. `action`: `"set"` (default), `"unset"` (back to 0/0 if in that state) or `"toggle"`. | `fullscreenstate` |
| `move({...})` | First key present wins: `direction` (+ `group_aware = true`); `x` and `y` (+ `relative = true`); `workspace` (+ `follow = false` for silent); `monitor` (+ `follow`, moves to its active workspace); `into_group`; `into_or_create_group`; `out_of_group` (direction or `true`). All accept `window`. | `movewindow`, `movewindoworgroup`, `moveactive`, `movewindowpixel`, `movetoworkspace`, `movetoworkspacesilent`, `moveintogroup`, `moveintoorcreategroup`, `moveoutofgroup` |
| `swap({...})` | First key present wins: `direction`; `target` (or `with`, `other`); `next = true`; `prev = true`. All accept `window`. | `swapwindow`, `swapnext` |
| `resize()` | No argument: resize with the mouse until the next key or button event. | `mouse` (`resizewindow`) |
| `resize({ x, y, relative?, window? })` | Size in pixels, or a delta with `relative = true`. | `resizeactive`, `resizewindowpixel` |
| `drag()` | Move with the mouse until the next key or button event. | `mouse` (`movewindow`) |
| `center({ window? })` | | `centerwindow` |
| `cycle_next({ next?, tiled?, floating?, window? })` | `next` defaults to `true`; `tiled`/`floating` restrict the candidates. | `cyclenext` |
| `bring_to_top()` | Focused window only. | `bringactivetotop` |
| `alter_zorder({ mode, window? })` | `"top"` or `"bottom"`. | `alterzorder` |
| `tag({ tag, window? })` | `"+t"` sets, `"-t"` unsets, `"t"` toggles. | `tagwindow` |
| `clear_tags({ window? })` | | |
| `set_prop({ prop, value, window? })` | `value` is a string or number. | `setprop` |
| `toggle_swallow()` | | `toggleswallow` |
| `deny_from_group({ action? })` | Focused window only. | `denywindowfromgroup` |

### Workspace (`hl.dsp.workspace.*`)

| Dispatcher | Notes | Replaces |
| --- | --- | --- |
| `toggle_special(name?)` | Positional string; no argument toggles the special workspace named `special`. | `togglespecialworkspace` |
| `move({ monitor, workspace? })` | Without `workspace`: the current one. | `movecurrentworkspacetomonitor`, `moveworkspacetomonitor` |
| `swap_monitors({ monitor1, monitor2 })` | Swap their active workspaces. | `swapactiveworkspaces` |
| `rename({ workspace, name? })` | No `name` clears it; special workspaces are left unchanged. | `renameworkspace` |

### Group (`hl.dsp.group.*`)

| Dispatcher | Notes | Replaces |
| --- | --- | --- |
| `toggle({ window? })` | Make or dissolve a group. | `togglegroup` |
| `next({ window? })`, `prev({ window? })` | Change the active member. | `changegroupactive f`/`b` |
| `active({ index, window? })` | 1-based; 0 or less selects the last member. | `changegroupactive N` |
| `move_window({ forward? })` | `forward` defaults to `true`. | `movegroupwindow` |
| `lock({ action? })` | All groups. | `lockgroups` |
| `lock_active({ action? })` | The focused group. | `lockactivegroup` |

### Cursor (`hl.dsp.cursor.*`)

| Dispatcher | Notes | Replaces |
| --- | --- | --- |
| `move({ x, y })` | Both required. | `movecursor` |
| `move_to_corner({ corner, window? })` | 0 bottom-left, 1 bottom-right, 2 top-right, 3 top-left. | `movecursortocorner` |

Legacy dispatchers with no Lua equivalent: `workspaceopt` and `setignoregrouplock` (both deprecated).

## Selectors

Selectors are strings, numbers or objects. Strings are resolved when the dispatcher runs; objects are converted
to strings when it is built.

### Window

Only mapped windows are considered; the first match wins.

| Selector | Matches |
| --- | --- |
| `class:RE`, `initialclass:RE`, `title:RE`, `initialtitle:RE`, `tag:RE` | RE2 full match on that property (any tag for `tag:`). Tags added by window rules end in `*`, so match them with `tag:foo\*?` (in Lua: `[[tag:foo\*?]]`). |
| `address:0x...` | Exact address, as in `HL.Window.address` |
| `pid:N` | Exact PID |
| `active` | The focused window |
| `floating`, `tiled` | First such window on the focused window's workspace |
| Anything else, including numbers | Only windows with an empty class: always use a prefix |
| `HL.Window` | Becomes `address:0x...` |

`active`, `floating` and `tiled` match by prefix (`activewindow` works too).

### Workspace

| Selector | Meaning |
| --- | --- |
| `N` (string or integer) | Workspace id; values below 1 become 1 |
| `+N`, `-N` | Relative to the active id (minimum 1) |
| `m+N`, `m-N`, `m~N` | Next/previous/N-th open workspace on the focused monitor (`+`/`-` wrap; `~N` past the end gives the last) |
| `e+N`, `e-N`, `e~N` | The same across all monitors |
| `r+N`, `r-N`, `r~N` | Relative/N-th id, skipping workspaces open on or bound to other monitors |
| `name:NAME` | Named workspace (created if missing) |
| `special`, `special:NAME` | Special workspace |
| `empty`, plus `m` and/or `n` | First empty workspace; `m`: not bound to another monitor; `n`: after the active id |
| `prev`, `previous`, anything else starting with `prev` | Previous workspace |
| `previous_per_monitor` | In `hl.dsp.focus` without `on_current_monitor`: the previous workspace on the focused monitor; elsewhere the same as `prev` |
| `next` | Active id + 1 |
| Other strings | Name of an existing workspace |
| `HL.Workspace` | Becomes its numeric id. Named and special workspaces have negative ids, which then parse as `-N`, so pass `name:`/`special:` strings for those. |

### Monitor

| Selector | Matches |
| --- | --- |
| `current` | The focused monitor |
| `l`, `r`, `u`, `d`, `t`, `b` | Neighbour in that direction (single letters only) |
| `+N`, `-N` | Relative position in the monitor list (wraps) |
| `N` | Monitor id |
| `desc:PREFIX` | Description starts with `PREFIX` |
| Other strings | Connector name, e.g. `DP-1` |
| `HL.Monitor` | Becomes its connector name |

## Lua functions as actions

A function action is called with no arguments and may run for at most 100 ms. An error appears as a
"Runtime error in lua" notification.

- `hl.dsp.*(...)` only builds a dispatcher. Inside a function, run it with `hl.dispatch(d)`; calling `d()`
  directly is an error.
- `hl.dispatch(d)` also accepts a function. It returns `{ ok = true, pass_event = bool }` or
  `{ ok = false, error, level, code }`. Return that table from the bind function to pass `ok` (used by
  `auto_consuming`) and `pass_event` on; any other return value counts as success.
- `hl.exec_cmd(cmd, rules?)` spawns immediately, without a dispatcher.

### Queries

| Query | Returns |
| --- | --- |
| `hl.get_active_window()` | `HL.Window` or `nil` |
| `hl.get_window(selector)`, `hl.get_last_window()`, `hl.get_urgent_window()` | `HL.Window` or `nil` |
| `hl.get_windows(filter?)` | Mapped windows only (`mapped = false`: only unmapped ones). Filter keys: `monitor`, `workspace`, `floating`, `mapped`, `class`, `title`, `tag`; `class`, `title` and `tag` are exact string comparisons, not regexes, so a tag added by a window rule needs its trailing `*` (a `tag` of `negative:foo` matches windows without `foo`). |
| `hl.get_active_workspace(monitor?)`, `hl.get_active_special_workspace(monitor?)`, `hl.get_last_workspace(monitor?)` | `HL.Workspace` or `nil` (default: focused monitor) |
| `hl.get_workspace(selector)`, `hl.get_workspaces()` | Existing workspaces only |
| `hl.get_workspace_windows(ws)` | Mapped windows on `ws` |
| `hl.get_active_monitor()`, `hl.get_monitor(selector)`, `hl.get_monitor_at_cursor()`, `hl.get_monitor_at({ x, y })` | `HL.Monitor` or `nil` |
| `hl.get_monitors()` | List of `HL.Monitor` |
| `hl.get_cursor_pos()` | `{ x, y }` |
| `hl.get_current_submap()` | Submap name (`""` for none) |

### Objects

Fields of an expired object read as `nil`. Integer fields such as `w.fullscreen` and `ws.windows` are
always truthy in Lua, so compare them with numbers.

| Object | Fields |
| --- | --- |
| `HL.Window` | `address`, `class`, `title`, `initial_class`, `initial_title`, `pid`, `workspace`, `monitor`, `floating`, `pinned`, `fullscreen` and `fullscreen_client` (0 none, 1 maximized, 2 fullscreen), `over_fullscreen`, `active`, `mapped`, `hidden`, `visible`, `accepts_input`, `at` and `size` (`{ x, y }`), `xwayland`, `group`, `tags`, `swallowing`, `focus_history_id`, `inhibiting_idle`, `xdg_tag`, `xdg_description`, `content_type`, `stable_id`, `layout` |
| `HL.Workspace` | `id`, `name`, `monitor`, `special`, `active`, `visible`, `windows` (count), `is_empty`, `has_urgent`, `has_fullscreen`, `fullscreen_mode`, `fullscreen_window`, `last_window`, `is_persistent`, `config_name`, `tiled_layout`, `groups` (count); methods `:get_windows()` (includes unmapped windows) and `:get_groups()` |
| `HL.Monitor` | `id`, `name`, `description`, `focused`, `active_workspace`, `active_special_workspace`, `x`, `y`, `position`, `width`, `height`, `size`, `refresh_rate`, `scale`, `transform`, `dpms_status`, `vrr_active`, `is_mirror`, `mirrors` |

## hyprctl under the Lua config

| Command | Behaviour |
| --- | --- |
| `hyprctl dispatch '<expr>'` | Evaluates `return hl.dispatch(<expr>)`, e.g. `hyprctl dispatch 'hl.dsp.focus({ workspace = 3 })'`. Old syntax (`dispatch workspace 3`) fails with a hint to update it. |
| `hyprctl eval '<lua>'` | Runs a Lua chunk (250 ms limit). Prints `ok` or the errors and warnings; return values are discarded and `print` writes to the Hyprland log. |
| `hyprctl keyword ...` | Refused: "keyword can't work with non-legacy parsers. Use eval." |
| `hyprctl binds -j` | `modmask` (bits above), `key` as written (only the last key of a chord; empty for `code:N`), `submap`, `description`. `dispatcher` is `__lua` for every Lua bind; there is no `ignore_mods` field. |
| `hyprctl configerrors` | Unreliable: every `eval`, and therefore every `dispatch`, clears the error list first. |

hyprctl exits 0 whenever Hyprland replies, so failures show only in the text: anything other than `ok` failed.

To check the config, use `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua`. It loads the config
without starting a compositor, prints `config ok` or the errors, and exits non-zero on errors. It sees
load-time errors only (key strings, options and the dispatcher checks listed under Dispatchers); function
bodies and everything else run at keypress.

## Sources

After a Hyprland upgrade, re-check this file against the new source:

```sh
src=$(nix build --no-link --print-out-paths ~/NixConfig#nixosConfigurations.worknix.pkgs.hyprland.src)
grep -o 'setFn(L, "[a-z_]*"' "$src/src/config/lua/bindings/LuaBindingsDispatchers.cpp"  # registered hl.dsp.* names
```

| Topic | Source file (function) |
| --- | --- |
| Key strings, bind options | `src/config/lua/bindings/LuaBindingsToplevel.cpp` (`parseKeyString`, `hlBind`) |
| `hl.dsp.*` | `src/config/lua/bindings/LuaBindingsDispatchers.cpp` (`registerDispatcherBindings` and the `hl*` factories) |
| Directions, toggles, selector arguments | `src/config/lua/bindings/LuaBindingsInternal.cpp` |
| Queries, object fields | `src/config/lua/bindings/LuaBindingsQuery.cpp`, `src/config/lua/objects/Lua{Window,Workspace,Monitor}.cpp` |
| Bind matching at runtime | `src/managers/KeybindManager.cpp` (`handleKeybinds`) |
| Selector strings | `src/Compositor.cpp` (`getWindowByRegex`, `getMonitorFromString`), `src/helpers/MiscFunctions.cpp` (`getWorkspaceIDNameFromString`) |
| Legacy flags and dispatchers | `src/config/legacy/ConfigManager.cpp` (`handleBind`), `src/config/legacy/DispatcherTranslator.cpp` |
| hyprctl | `src/debug/HyprCtl.cpp`, `hyprctl/src/main.cpp`, `src/config/lua/ConfigManager.cpp` (`eval`) |
