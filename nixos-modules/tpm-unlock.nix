/*
TPM unlock of the root volume without a boot-time PIN, plus the two things the
genuine signed boot chain would otherwise trust blindly before the disk opens:

- Which LUKS volume it opens. The TPM releases the key to anything that boots
  with the same PCR 0+7, so a foreign volume under by-partlabel/luks (a USB
  stick will do), unlocked with the attacker's passphrase, would get to ask the
  TPM for the real key. fixate-volume-key= makes systemd-cryptsetup refuse any
  volume whose key differs, whichever way it is unlocked.
- Where it resumes from. Without resume= on the command line, the initrd
  resumes from the device named in the unauthenticated EFI variable
  HibernateLocation, i.e. from a forged image. resume= with the swapfile's
  offset takes precedence over it.

Both values come from the machine itself (see TPM_HARDENINGS.md):

  sudo btrfs inspect-internal map-swapfile -r /swap/swapfile   # resumeOffset
  # volumeKeyId: systemd-cryptsetup prints it when given a wrong one

The pin changes when the volume is re-encrypted or the mapping renamed, the
offset when the swapfile is recreated. Changing a passphrase or enrolling the
TPM changes neither. Once the pin is in, delete the older generations: their
initrds still open any volume and stay in the (signed) boot menu.
*/
{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.configured.tpmUnlock;
  mapping = "/dev/mapper/${cfg.device}";
  hasSwap = config.swapDevices != [];
in {
  options.configured.tpmUnlock = {
    enable = mkOption {
      type = types.bool;
      default = config.configured.limine.secureboot;
      defaultText = literalExpression "config.configured.limine.secureboot";
      description = ''
        Unlock the root volume with the TPM (enrolled by hand with
        systemd-cryptenroll --tpm2-pcrs=0+7, no PIN). Only meaningful with
        Secure Boot and Limine's enrolled config, hence on wherever those are.
      '';
    };
    device = mkOption {
      type = types.str;
      default = "cryptroot";
      description = "Name of the root volume's mapping; part of volumeKeyId.";
    };
    volumeKeyId = mkOption {
      type = types.nullOr (types.strMatching "[0-9a-f]{64}");
      default = null;
      description = ''
        Expected identity of the root volume's key (crypttab
        fixate-volume-key=). Applies even without enable, so it can be in
        place before the first signed boot loader exists.
      '';
    };
    resumeOffset = mkOption {
      type = types.nullOr types.ints.unsigned;
      default = null;
      description = ''
        resume_offset of the swapfile inside the root volume. Pins hibernation
        resume to that volume instead of the EFI variable HibernateLocation.
      '';
    };
  };

  config = mkMerge [
    (mkIf (cfg.volumeKeyId != null || cfg.resumeOffset != null) {
      assertions = [
        {
          assertion = config.boot.initrd.luks.devices ? ${cfg.device};
          message = "configured.tpmUnlock: there is no LUKS device '${cfg.device}' in boot.initrd.luks.devices.";
        }
      ];
    })

    (mkIf (cfg.volumeKeyId != null) {
      boot.initrd.luks.devices.${cfg.device}.crypttabExtraOpts = ["fixate-volume-key=${cfg.volumeKeyId}"];
    })

    (mkIf (cfg.resumeOffset != null) {
      boot = {
        resumeDevice = mapping;
        kernelParams = ["resume_offset=${toString cfg.resumeOffset}"];
      };
    })

    (mkIf cfg.enable {
      /*
      Token plugins are off once fixate-volume-key= is set, so the TPM has to
      be asked for here. Without a matching token it falls back to the
      passphrase.
      */
      boot.initrd.luks.devices.${cfg.device}.crypttabExtraOpts = ["tpm2-device=auto"];

      # Nothing to resume from, so HibernateLocation must not name a device either
      boot.kernelParams = mkIf (!hasSwap && cfg.resumeOffset == null) ["noresume"];

      warnings =
        optional (cfg.volumeKeyId == null) ''
          configured.tpmUnlock: no volumeKeyId, so the initrd opens any volume
          labelled as the root volume and lets it ask the TPM for the real key.
          See TPM_HARDENINGS.md for how to read the value.
        ''
        ++ optional (hasSwap && cfg.resumeOffset == null) ''
          configured.tpmUnlock: no resumeOffset, so hibernation resumes from
          wherever the EFI variable HibernateLocation points. Read it with
          sudo btrfs inspect-internal map-swapfile -r <swapfile>.
        '';
    })
  ];
}
