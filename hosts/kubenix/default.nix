{
  inputs,
  globalArgs,
  makeTheme,
  modules,
  self,
  ...
}: let
  k8sArgs =
    globalArgs
    // rec {
      clusterRoles = ["node"];
      masterIpv4 = "10.0.0.2";
      domain = "kubenix.niveri.dev";
      masterHostname = "falkenberg";
      masterFqdn = "${masterHostname}.${domain}";
      k8sPort = 6443;
    };
in {
  falkenberg = inputs.nixpkgs.lib.nixosSystem (let
    systemArgs =
      k8sArgs
      // {
        clusterRoles = ["master" "node"];
        system = "aarch64-linux";
        theme = makeTheme {
          primary = "orange";
          secondary = "green";
        };
        ipv4 = "91.99.10.215";
        ipv6 = "2a01:4f8:c013:e704::1";
        hostname = k8sArgs.masterHostname;
      };
  in {
    inherit (systemArgs) system;
    modules =
      [
        ./falkenberg/hardware-configuration.nix
        ./falkenberg/disks.nix

        ./kubernetes.nix
        {config._module.args = {inherit systemArgs self inputs;};}
      ]
      ++ modules;
  });
  stadeln = inputs.nixpkgs.lib.nixosSystem (let
    systemArgs =
      k8sArgs
      // {
        system = "aarch64-linux";
        theme = makeTheme {
          primary = "orange";
          secondary = "green";
        };
        ipv4 = "91.107.238.152";
        ipv6 = "2a01:4f8:1c1c:373e::1";
        hostname = "stadeln";
      };
  in {
    inherit (systemArgs) system;
    modules =
      [
        ./stadeln/hardware-configuration.nix
        ./stadeln/disks.nix

        ./kubernetes.nix
        {config._module.args = {inherit systemArgs self inputs;};}
      ]
      ++ modules;
  });
  ronhof = inputs.nixpkgs.lib.nixosSystem (let
    systemArgs =
      k8sArgs
      // {
        system = "aarch64-linux";
        theme = makeTheme {
          primary = "orange";
          secondary = "green";
        };
        ipv4 = "91.99.63.12";
        ipv6 = "2a01:4f8:1c1b:f047::1";
        hostname = "ronhof";
      };
  in {
    inherit (systemArgs) system;
    modules =
      [
        ./ronhof/hardware-configuration.nix
        ./ronhof/disks.nix

        ./kubernetes.nix
        {config._module.args = {inherit systemArgs self inputs;};}
      ]
      ++ modules;
  });
}
