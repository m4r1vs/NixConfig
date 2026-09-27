{
  lib,
  pkgs,
  systemArgs,
  ...
}: {
  wsl = {
    enable = true;
    defaultUser = systemArgs.username;
    interop.includePath = false;
  };

  services.openssh.enable = lib.mkForce false;

  boot.loader.systemd-boot.enable = lib.mkForce false;

  environment.systemPackages = with pkgs;
  # Use the Windows OpenSSH (and its agent) from inside WSL
    map (name: writeShellScriptBin name ''exec /mnt/c/WINDOWS/System32/OpenSSH/${name}.exe "$@"'')
    ["ssh" "scp" "sftp" "ssh-add" "ssh-agent" "ssh-keygen" "ssh-keyscan"]
    ++ [
      (writeShellScriptBin "op" ''
        # Forward all OP_* variables to the Windows 1Password CLI
        mapfile -d "" -t op_env_vars < <(env -0 | grep -z '^OP_' | cut -z -d= -f1)
        if ((''${#op_env_vars[@]})); then
          export WSLENV="''${WSLENV:+$WSLENV:}$(IFS=:; echo "''${op_env_vars[*]}")"
        fi
        exec /mnt/c/Users/mariu/AppData/Local/Microsoft/WinGet/Links/op.exe "$@"
      '')
    ];

  system = {
    nixos.label = systemArgs.hostname + ".niveri.dev";
  };
}
