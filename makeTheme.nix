{
  primary,
  secondary,
}: let
  colors = {
    orange = {
      hex = "#db8c4b";
      rgb = "219, 140, 75";
    };
    green = {
      hex = "#6c7b2e";
      rgb = "108, 123, 46";
    };
    red = {
      hex = "#FE3700";
      rgb = "254,55,0";
    };
    cyan = {
      hex = "#5ABDAC";
      rgb = "90, 189, 172";
    };
    magenta = {
      hex = "#B74583";
      rgb = "183, 69, 131";
    };
    purple = {
      hex = "#735eb5";
      rgb = "115, 94, 181";
    };
    purplish_grey = {
      hex = "#A699D0";
      rgb = "166, 153, 208";
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
