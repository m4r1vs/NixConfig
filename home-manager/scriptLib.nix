/*
Helpers passed to every script file as `helpers` (see makeScripts.nix).
Lives outside scripts/ so it isn't picked up as a script itself.
*/
{
  pkgs,
  config,
}: let
  inherit (pkgs) lib;

  /*
  Like writeShellApplication (runtimeInputs, strict bash, build-time
  shellcheck), but $out is the script file itself rather than $out/bin/name,
  so it can be interpolated as "${scripts.foo}" like writeShellScript.
  */
  mkScript = {
    name,
    text,
    runtimeInputs ? [],
    bashOptions ? ["errexit" "nounset" "pipefail"],
    excludeShellChecks ? [],
  }:
    pkgs.writeTextFile {
      inherit name;
      executable = true;
      text = ''
        #!${pkgs.runtimeShell}
        ${lib.concatMapStringsSep "\n" (option: "set -o ${option}") bashOptions}
        ${lib.optionalString (runtimeInputs != []) ''
          export PATH="${lib.makeBinPath runtimeInputs}:$PATH"
        ''}
        ${text}
      '';
      checkPhase = ''
        runHook preCheck
        ${pkgs.stdenv.shellDryRun} "$target"
        ${lib.optionalString pkgs.shellcheck-minimal.compiler.bootstrapAvailable ''
          ${lib.getExe pkgs.shellcheck-minimal} --severity=warning ${
            lib.optionalString (excludeShellChecks != [])
            "--exclude ${lib.concatStringsSep "," excludeShellChecks}"
          } "$target"
        ''}
        runHook postCheck
      '';
      meta.mainProgram = name;
    };

  # Same as mkScript, but keeps today's writeShellScript semantics (no set -euo)
  mkLegacyScript = args: mkScript ({bashOptions = [];} // args);

  # darwin has no configured.system-sounds, hence the attrByPath
  sounds = lib.attrByPath ["configured" "system-sounds"] {enable = false;} config;

  # "" or a backgrounded mpv call playing the given system sound
  playSound = kind:
    lib.optionalString (sounds.enable && (sounds.${kind}.enable or false))
    "${lib.getExe pkgs.mpv} --no-video --no-config --no-terminal --volume=80 ${sounds.${kind}.soundFile} >/dev/null 2>&1 &";

  # Clipboard commands of the active session, so scripts don't need `eval`
  clipboard =
    if lib.attrByPath ["configured" "i3" "enable"] false config
    then {
      copy = "${pkgs.xclip}/bin/xclip -selection clipboard -i";
      paste = "${pkgs.xclip}/bin/xclip -selection clipboard -o";
    }
    else {
      copy = "${pkgs.wl-clipboard}/bin/wl-copy";
      paste = "${pkgs.wl-clipboard}/bin/wl-paste -n";
    };
in {
  inherit mkScript mkLegacyScript playSound clipboard;
}
