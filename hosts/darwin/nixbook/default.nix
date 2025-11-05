{systemArgs, ...}: {
  users.users.mn.home = "/Users/${systemArgs.username}";

  configured.darwin.enable = true;

  homebrew = {
    enable = true;
    casks = [
      "middleclick"
    ];
  };

  system = {
    defaults = {
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
      };
    };
  };
}
