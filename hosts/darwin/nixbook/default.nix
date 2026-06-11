{systemArgs, ...}: {
  users.users.mn.home = "/Users/${systemArgs.username}";

  configured.darwin.enable = true;

  homebrew = {
    casks = [
      "middleclick"
    ];
  };

  networking = {
    computerName = "Marius' NixBook";
  };
}
