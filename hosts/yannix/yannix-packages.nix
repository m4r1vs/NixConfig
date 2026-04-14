{
  pkgs,
  systemArgs,
  ...
}: {
  home-manager.users.${systemArgs.username}.home.packages = with pkgs; [
    bazaar # Gnome App Store
  ];
}
