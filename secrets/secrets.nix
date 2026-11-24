let
  marius = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN6sMTjk1LAXVX9qRKsB3VgsfqCfcJSeosgoYWTgSHW";
  worknix = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHyXq6MxwAcn55nD22wBAdUC4gikMSF78zlT/MMQCbmx";
in {
  "hey-computer-memory.age".publicKeys = [
    marius
    worknix
  ];
}
