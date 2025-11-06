{systemArgs, ...}: {
  users.users.mn.home = "/Users/${systemArgs.username}";

  configured.darwin.enable = true;

  homebrew = {
    enable = true;
    casks = [
      "middleclick"
    ];
  };

  networking = {
    computerName = "Marius' NixBook";
  };
}
