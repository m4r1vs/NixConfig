{
  host,
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.programs.configured.ssh;
  inherit (host) isDarwin isDev;
  # Own machines that announce themselves via mDNS/Bonjour (configured.mdns
  # on NixOS, networking.localHostName on darwin).
  lanHosts = ["worknix" "nixpad" "desknix" "nixbook"];
in {
  options.programs.configured.ssh = {
    enable = mkEnableOption "Secure Shell";
  };
  config = mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      # `ssh worknix` -> worknix.local, resolved on whatever LAN we're on.
      settings."Host ${concatStringsSep " " lanHosts}" = mkIf isDev (hm.dag.entryBefore ["Host *"] {
        HostName = "%h.local";
      });
      settings."Host *" = {
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
        IdentityAgent =
          if isDarwin
          then "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\""
          else "\"~/.1password/agent.sock\"";
      };
    };
  };
}
