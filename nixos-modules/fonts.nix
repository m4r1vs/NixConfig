{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.configured.fonts;
in {
  options.configured.fonts = {
    enable = mkEnableOption "Enable fonts.";
  };
  config = mkIf cfg.enable {
    fonts = {
      enableDefaultPackages = true;

      fontconfig = {
        defaultFonts = {
          serif = ["EB Garamond 08"];
          sansSerif = ["Ubuntu"];
          monospace = ["JetBrainsMono Nerd Font Propo"];
          emoji = ["Apple Color Emoji"];
        };
      };

      packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        ubuntu_font_family
        eb-garamond
        (stdenv.mkDerivation {
          name = "Apple Color Emoji Font";
          src = fetchurl {
            url = "https://github.com/samuelngs/apple-emoji-linux/releases/download/v18.4/AppleColorEmoji.ttf";
            hash = "sha256-pP0He9EUN7SUDYzwj0CE4e39SuNZ+SVz7FdmUviF6r0=";
          };
          dontUnpack = true;
          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/fonts/truetype
            cp $src $out/share/fonts/truetype/AppleColorEmoji.ttf

            runHook postInstall
          '';
        })
        (stdenv.mkDerivation {
          name = "Samsung Classic Clock Font";
          src = ../assets/fonts/samsung/samsung-clock-classic.ttf;
          dontUnpack = true;
          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/fonts/truetype
            cp $src $out/share/fonts/truetype/SamsungClockClassic.ttf

            runHook postInstall
          '';
        })
      ];
      fontDir.enable = true;
    };
  };
}
