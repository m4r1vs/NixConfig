{
  lib,
  config,
  osConfig,
  systemArgs,
  ...
}:
with lib; let
  isDesktop = osConfig.configured ? desktop && osConfig.configured.desktop.enable;
  cfg = config.programs.configured.spotify-player;
in {
  options.programs.configured.spotify-player = {
    enable = mkEnableOption "Spotify Terminal Player";
  };
  config = mkIf cfg.enable {
    programs.spotify-player = {
      enable = true;
      keymaps = [
        {
          command = "None";
          key_sequence = "q";
        }
        {
          command = "None";
          key_sequence = "l";
        }
        {
          command = "PreviousPage";
          key_sequence = "h";
        }
        {
          command = "ChooseSelected";
          key_sequence = "l";
        }
        {
          command = "PreviousPage";
          key_sequence = "C-o";
        }
      ];
      settings = {
        client_id = "228dbbe5c96a418586e5847a6d2e1a73";
        theme = "dracula";
        client_port = 8080;
        login_redirect_uri = "http://127.0.0.1:8888/login";
        playback_format = ''
          {status} {track} • {artists}
          {album}
          {metadata}'';
        tracks_playback_limit = 50;
        app_refresh_duration_in_ms = 32;
        playback_refresh_duration_in_ms = 0;
        page_size_in_rows = 20;
        play_icon = " ";
        pause_icon = "󰕿";
        liked_icon = " ";
        border_type = "Double";
        progress_bar_type = "Rectangle";
        enable_cover_image_cache = true;
        enable_streaming =
          if isDesktop
          then "Always"
          else "Never";
        notify_streaming_only = true;
        default_device = systemArgs.hostname;
        cover_img_width = 7;
        cover_img_length = 16;
        seek_duration_secs = 5;
        layout = {
          playback_window_position = "Bottom";
          playback_window_height = 6;
          library = {
            playlist_percent = 40;
            album_percent = 40;
          };
        };
        device = {
          name = systemArgs.hostname;
          device_type = "speaker";
          volume = 100;
          bitrate = 320;
          audio_cache = true;
          normalization = false;
          autoplay = false;
        };
      };
    };
  };
}
