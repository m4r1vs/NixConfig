let
  marius = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN6sMTjk1LAXVX9qRKsB3VgsfqCfcJSeosgoYWTgSHW";
  worknix = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHyXq6MxwAcn55nD22wBAdUC4gikMSF78zlT/MMQCbmx";
  worknixKeys = [
    marius
    worknix
  ];
in {
  "hey-computer-memory.age".publicKeys = worknixKeys;
  "hey-computer-notification-senders.age".publicKeys = worknixKeys;
  "hey-computer-whatsapp-allow.age".publicKeys = worknixKeys;
  "hey-computer-signal-allow.age".publicKeys = worknixKeys;
  "hey-computer-signal-account.age".publicKeys = worknixKeys;
  "google-workspace-client-secret.age".publicKeys = worknixKeys;
  "slack-mcp-xoxc.age".publicKeys = worknixKeys;
  "slack-mcp-xoxd.age".publicKeys = worknixKeys;
}
