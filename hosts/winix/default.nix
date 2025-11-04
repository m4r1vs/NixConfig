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

  configured = {
    fonts.enable = true;
  };

  services.openssh.enable = lib.mkForce false;

  boot.loader.systemd-boot.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "ssh" "/mnt/c/WINDOWS/System32/OpenSSH/ssh.exe $@")
    (writeShellScriptBin "scp" "/mnt/c/WINDOWS/System32/OpenSSH/scp.exe $@")
    (writeShellScriptBin "sftp" "/mnt/c/WINDOWS/System32/OpenSSH/sftp.exe $@")
    (writeShellScriptBin "ssh-add" "/mnt/c/WINDOWS/System32/OpenSSH/ssh-add.exe $@")
    (writeShellScriptBin "ssh-agent" "/mnt/c/WINDOWS/System32/OpenSSH/ssh-agent.exe $@")
    (writeShellScriptBin "ssh-keygen" "/mnt/c/WINDOWS/System32/OpenSSH/ssh-keygen.exe $@")
    (writeShellScriptBin "ssh-keyscan" "/mnt/c/WINDOWS/System32/OpenSSH/ssh-keyscan.exe $@")
    (writeShellScriptBin "op" ''
      mapfile -d op_env_vars < <(env -0 | grep -z ^OP_ | cut -z -d= -f1)
      export WSLENV="''${WSLENV:-}:$(IFS=:; echo "''${op_env_vars

      }")"
      exec /mnt/c/Users/mariu/AppData/Local/Microsoft/WinGet/Links/op.exe "$@"
    '')
  ];

  system = {
    nixos.label = systemArgs.hostname + ".niveri.dev";
  };
}
