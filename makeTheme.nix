{
  primary,
  secondary,
}: let
  colors = {
    orange = {
      hex = "#f7821B";
      rgb = "247,130,27";
    };
    green = {
      hex = "#658257";
      rgb = "101,130,87";
    };
    red = {
      hex = "#FE3700";
      rgb = "254,55,0";
    };
    purplish_grey = {
      hex = "#6c5e73";
      rgb = "108,94,115";
    };
  };
in {
  backgroundColor = "#15130F";
  backgroundColorRGB = "21,19,15";

  backgroundColorLight = "#F5E6CC";
  backgroundColorLightRGB = "245,230,204";

  primaryColor = colors."${primary}";
  secondaryColor = colors."${secondary}";
}
