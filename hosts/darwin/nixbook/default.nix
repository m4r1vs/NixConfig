_: {
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
