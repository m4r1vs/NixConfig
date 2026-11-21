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
    # Bonjour name, so the laptops reach it as nixbook.local (otherwise
    # macOS derives it from computerName: Marius-NixBook.local)
    localHostName = "nixbook";
  };
}
