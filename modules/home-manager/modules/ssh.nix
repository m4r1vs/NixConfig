{
  lib,
  config,
  osConfig,
  ...
}:
with lib; let
  cfg = config.programs.configured.ssh;
  isDarwin = osConfig.configured.darwin.enable;
in {
  options.programs.configured.ssh = {
    enable = mkEnableOption "Secure Shell";
  };
  config = mkIf cfg.enable {
    programs.ssh = {
      enable = true;
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
    };
  };
}
