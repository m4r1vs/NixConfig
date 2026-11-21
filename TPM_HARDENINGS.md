# TPM hardenings

How well the TPM-based disk unlock of these hosts holds up, what could be added without a boot-time
PIN, and what was ruled out. Written on 2026-11-20 against the versions this flake pins:
systemd 260.5, Limine 12.5.2, NixOS 26.05.

Nothing here is deployed, and nothing was tested on a real boot. Every claim carries one of these
labels:

- **read**: taken from the source or documentation of the pinned version
- **evaluated**: from `nix eval` or from inspecting worknix without root
- **tested**: run on a throwaway LUKS2 image file, as a normal user
- **inferred**: follows from the above, but not observed

## Starting point

- The root volume is LUKS2, opened in the systemd initrd as `cryptroot` from
  `/dev/disk/by-partlabel/luks`. Root is mounted from `/dev/mapper/cryptroot`. (evaluated)
- On worknix, nixpad and desknix the disk key is released by the TPM, enrolled by hand with
  `systemd-cryptenroll --tpm2-pcrs=0+7`. The initrd crypttab has no TPM option; the unlock goes
  through libcryptsetup's token plugin. (evaluated, read)
- Secure Boot is on with own sbctl keys. Limine is signed and carries the hash of `limine.conf`,
  which in turn carries the hashes of kernel and initrd. With both in place Limine refuses a
  changed config, kernel or initrd and disables its editor. (read: Limine `USAGE.md`)
- yannix has no TPM unlock yet and Secure Boot is off there. The same setup is planned for it.

PCR 0 is the firmware code. PCR 7 is the Secure Boot state, the key databases and the key that
verified the boot loader. It records the signing key, not which build of the loader ran.

## The gap: a substituted root volume

The TPM releases the disk key to anything that boots with the same PCR 0 and 7. It does not check
which volume the initrd then opens. (inferred; this is a published technique, see
<https://oddlama.org/blog/bypassing-disk-encryption-with-tpm2-unlock/>)

1. The attacker prepares an own LUKS volume with a known passphrase and a root file system of
   their choosing, and makes it the one the initrd finds under the partition label `luks`.
2. The genuine, signed boot chain starts. The TPM token does not fit the foreign volume, so the
   initrd asks for a passphrase; the attacker types theirs.
3. The attacker's system now runs as root with PCR 0 and 7 unchanged, and asks the TPM for the key
   of the real volume.

The lock screen never runs. This takes preparation and skill, not hours with the device.

## The second gap: a forged hibernation image

Without `resume=` on the kernel command line, `systemd-hibernate-resume` in the initrd resumes from
the device named in the EFI variable `HibernateLocation` (`acquire_hibernate_info()` in
`src/hibernate-resume/hibernate-resume-config.c`). (read) The only check is that the os-release
`ID` and `IMAGE_ID` match, i.e. "nixos" and nothing. (read) The variable is not authenticated,
and none of these hosts sets `resume=`. (evaluated)

An attacker who can run anything on the machine once (Secure Boot off in the firmware, then back
on, which leaves PCR 7 as it was) points the variable at a swap partition on a stick holding an
image of their making. The genuine boot chain resumes it with PCR 0 and 7 unchanged, and it asks
the TPM for the key. (inferred)

With `resume=` set, the command line wins over the variable, including the offset, which then
defaults to 0. (read) So pinning needs `resume_offset=` as well, or hibernation breaks on the
btrfs swapfile. A host without swap gets `noresume`.

## Registers checked

| PCR | Holds | Use against the gap |
| --- | --- | --- |
| 0 | Firmware code | Already bound |
| 7 | Secure Boot state, keys, signer of the loader | Already bound; identical during the attack |
| 1 to 3 | Firmware settings, option ROMs | No help, and likely to change with docks and settings (inferred) |
| 4 | Boot loader binary | Changes on every rebuild, because the config hash is written into the binary before signing (read) |
| 5 | Partition table | Unchanged by the swap (inferred) |
| 8 | Limine: command line and file paths | Changes on every rebuild, since the command line names the generation (read); identical during the attack |
| 9 | Limine: config, kernel and initrd contents | Changes on every rebuild (read); identical during the attack |
| 10 | Kernel integrity log | Not a fixed value (evaluated: non-zero on worknix) |
| 11 to 13 | systemd stub and boot phases | Never extended with Limine (evaluated: zero on worknix) |
| 15 | System identity, including volume keys | Not extended with Limine, see below |

Binding to 4, 8 or 9 would require a new enrolment after every rebuild, which rules out the
automatic updates.

## PCR 15: ruled out

The usual advice is `tpm2-measure-pcr=yes` in crypttab plus an enrolment that expects PCR 15 to be
empty: once any volume has been opened the register has changed and the key can no longer be
released.

- The option exists, and an expected value can be given at enrolment
  (`--tpm2-pcrs=15:sha256=<digest>`). (read)
- systemd only performs the measurement when the system was booted through its own UEFI stub
  (`efi_measured_uki()` in `src/shared/efi-loader.c`). With Limine it logs a debug line and
  skips it. (read) On worknix `bootctl` reports "Measured UKI: no" and PCRs 11 to 15 are all
  zero. (evaluated)
- `SYSTEMD_FORCE_MEASURE=1` overrides the test, documented as being "for testing purposes". (read)
- A failed measurement is ignored: the call is marked "OK if fails". (read)

The same condition disables the boot phase units (`systemd-pcrphase-*`), the NixOS options built
on them (`boot.initrd.systemd.tpm2.pcrphases.enable`) and the newer NvPCRs.

## Recommended: pin the volume key

`fixate-volume-key=` is a crypttab option new in systemd 260. It holds the expected identity of
the volume key, and systemd-cryptsetup refuses to open a volume that has another one. A
substituted volume then never becomes the root file system, whichever way it is unlocked.

What is known:

- The pin is the lowercase hex HMAC-SHA256, keyed with the volume key, of
  `cryptsetup:<mapping name>:<LUKS UUID>`. (read: `src/shared/cryptsetup-util.c`; tested: the
  formula reproduces the value systemd prints)
- With the option set, the token plugins are switched off and every way of unlocking goes through
  the same check. (read: `use_token_plugins()` and the `measured_crypt_activate_*` wrappers in
  `src/cryptsetup/cryptsetup.c`)
- A wrong pin is refused even with the correct passphrase; the correct pin passes the check.
  (tested)
- The mapping name is part of the pin: the same volume gives another value under another name.
  (tested)
- It does not depend on the TPM or on any PCR. (read)

What follows from that:

- Because the plugins are off, the TPM unlock needs `tpm2-device=auto` in the same crypttab
  entry. Without it the passphrase prompt returns. (inferred, not booted) While no token is
  enrolled it falls back to the passphrase, see Configuration. (read)
- The pin only means something once Secure Boot is on and Limine's config hash is enrolled,
  because that is what fixes the initrd (which holds the crypttab) and the command line.
- The pin changes when the volume key changes (re-encryption, a new LUKS volume) or when the
  mapping is renamed. Changing a passphrase or enrolling the TPM does not change it. (inferred
  from the formula)
- The pin is a keyed hash and sits readable on the boot partition. (read)

### Configuration

`nixos-modules/tpm-unlock.nix` does both pins. In a host's NixOS configuration (for yannix:
`host/default.nix` in its own repository):

```nix
configured.tpmUnlock = {
  volumeKeyId = "<pin>";
  resumeOffset = <offset>; # sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
};
```

- `volumeKeyId` adds `fixate-volume-key=` whenever it is set, with or without Secure Boot, so it
  can come first as described below.
- `configured.tpmUnlock.enable` follows `configured.limine.secureboot` and adds
  `tpm2-device=auto`. It warns while either value is missing.
- `resumeOffset` adds `resume=/dev/mapper/cryptroot resume_offset=<offset>`.

On worknix this evaluates to
`cryptroot /dev/disk/by-partlabel/luks - tpm2-device=auto,fixate-volume-key=<pin>,discard,no-read-workqueue,no-write-workqueue`
in the initrd crypttab. (evaluated)

`tpm2-device=auto` before any token is enrolled is harmless: with the plugins off,
systemd-cryptsetup looks for the `systemd-tpm2` token itself and, if there is none or none matches,
logs "No TPM2 metadata enrolled in LUKS2 header, falling back to traditional unlocking" and asks
for the passphrase. Any other TPM error falls back the same way.
(read: `attach_luks_or_plain_or_bitlk_by_tpm2()` in `src/cryptsetup/cryptsetup.c`)

### Getting the pin of an existing volume

systemd documents this for new volumes only (systemd-repart). For an existing one, systemd prints
the real value when it is given a wrong one. Two things get in the way on a running system:
as root, `attach` returns at once because `cryptroot` is already open (read), and a normal user
cannot read the partition. A copy of the LUKS header, read as a normal user, avoids both.
(tested with a key file on a throwaway image; the passphrase is therefore piped in as one)

```sh
sudo cryptsetup luksHeaderBackup /dev/disk/by-partlabel/luks --header-backup-file /root/luks-header.img
sudo install -m 600 -o "$USER" /root/luks-header.img "$XDG_RUNTIME_DIR/luks-header.img"

# as the normal user, with the real mapping name; type the disk passphrase when asked
read -rs pw; printf '%s' "$pw" | systemd-cryptsetup attach cryptroot "$XDG_RUNTIME_DIR/luks-header.img" /dev/stdin fixate-volume-key=0000; unset pw
# prints: Volume key id: '<pin>' does not match the expectation: '0000'.

rm "$XDG_RUNTIME_DIR/luks-header.img"
```

Nothing is opened by this: without root there is no device-mapper access. The header backup is
worth keeping off the machine in any case.

### Order of the steps

Any signed loader whose config lists an initrd without the pin boots with the same PCR 0 and 7,
whether it is picked from the menu or restored from an old copy of the boot partition. So the pin
has to exist before the first signed loader does:

1. Add the pin (without `tpm2-device=auto`), rebuild.
2. Reboot and unlock with the passphrase. If the pin is wrong the disk stays closed: pick the
   previous generation in the boot menu and correct it.
3. Delete the generations from before the pin.
4. Only then switch on Secure Boot signing, add `tpm2-device=auto`, and enrol the TPM.

On worknix, nixpad and desknix signed boot chains without the pin already exist on the boot
partition. Adding the pin there still stops the attack for anyone who has no older copy of that
partition, once the older generations are deleted and a rebuild has rewritten `limine.conf`.
Closing it fully would mean new sbctl keys (which changes PCR 7) and a new enrolment. Decided on
2026-11-20: not done, the risk is accepted.

For yannix, `secureBoot.enable` without keys in `/var/lib/sbctl` makes the Limine install fail
(`limine-install.py`). (read) So step 4 is done by hand on the machine (`sbctl create-keys`,
firmware in setup mode, `sbctl enroll-keys`), not through the daily auto-upgrade, and the TPM is
enrolled only once Secure Boot is on, since PCR 7 changes with it.

### Further, without code

- A firmware supervisor password. It is asked only on entering the setup, not at boot, and stops
  the Secure Boot off-and-on that leaves PCR 7 unchanged. (inferred; a CMOS reset may get around
  it on some boards)
- After the TPM is enrolled, `cryptsetup luksDump` should show `tpm2_srk` on the
  `systemd-tpm2` token. With it, systemd-cryptsetup refuses a TPM whose storage root key differs,
  which guards against an interposer on the TPM bus. (read)

## Alternative: a TPM PIN

`systemd-cryptenroll --tpm2-with-pin=yes` makes the TPM ask for a short code before it releases
the key. The TPM limits wrong attempts, so the code can be much shorter than the passphrase, and
it is useless without this machine. It covers the substituted volume and the attacks below. The
cost is a prompt at every boot.

## What stays open without a PIN

- **A laptop that powers on unlocked.** Once the disk opens by itself, a stolen machine can be
  switched on and the key is in memory. Attacks on memory or on the TPM's bus then apply to a
  machine that was off. The pin does nothing against those.
- **The lock screen as the only barrier** for anyone at the keyboard, with the machine fully up
  (network, sshd) before anyone has authenticated. The Hyprland autologin session locks itself
  with hyprlock at once and ends if hyprlock dies; i3 and gamescope start at tuigreet. (read)

## Tested in a VM

A NixOS VM test (swtpm, OVMF, systemd initrd, systemd 260.5; root on LUKS2 under
`/dev/disk/by-label/luks` with `tpm2-device=auto,fixate-volume-key=<pin>`, TPM enrolled on PCR 7).
The pin was computed outside the VM with the formula above and matched what systemd computed.
(tested, 2026-11-20)

1. Correct pin, TPM token enrolled: unlocks with no prompt, root on `/dev/mapper/cryptroot`.
2. Correct pin, token wiped: asks for the passphrase and boots with it.
3. Wrong pin, TPM releases the key: refused ("Volume key id: … does not match the expectation").
4. The genuine volume relabelled and a foreign LUKS volume labelled `luks`, unlocked with its own
   passphrase: refused the same way. This is the substitution attack from the top, stopped.

## Not done yet

- A boot with the pin on a real machine.
- Hibernation and resume with `resume=` and `resume_offset=` pinned.
- Reading the pin from a header copy with a typed passphrase instead of a key file.
