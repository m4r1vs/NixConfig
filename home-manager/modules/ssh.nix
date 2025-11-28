{
  lib,
  config,
  systemArgs,
  ...
}:
with lib; let
  cfg = config.programs.configured.ssh;
  isDarwin = systemArgs.system == "aarch64-darwin";
in {
  options.programs.configured.ssh = {
    enable = mkEnableOption "Secure Shell";
  };
  config = mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      extraConfig =
        if isDarwin
        then ''
          Host *
              IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        ''
        else ''
          Host *
              IdentityAgent ~/.1password/agent.sock
        '';
      matchBlocks."*" = {
        forwardAgent = false;
        addKeysToAgent = "no";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
    };
  };
}
