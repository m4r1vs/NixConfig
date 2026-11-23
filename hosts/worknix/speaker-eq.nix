{pkgs, ...}: let
  cardName = "alsa_card.pci-0000_65_00.6";
  sinkName = "alsa_output.pci-0000_65_00.6.analog-stereo";
  speakerRoute = "analog-output-speaker";
  filterNodeName = "effect_input.worknix_speaker_eq";
in {
  services.pipewire = {
    extraLv2Packages = [pkgs.lsp-plugins];

    /*
    In-process speaker EQ + brickwall limiter for worknix's 14" Uniwill
    speakers (Conexant/Senary SN6140). Runs as a WirePlumber smart filter
    bound to the analog HDA sink so @DEFAULT_SINK@, Waybar, volume keys,
    and external outputs (HDMI, Bluetooth, USB DACs) stay untouched.
    */
    extraConfig.pipewire."92-worknix-speaker-eq" = {
      "context.modules" = [
        {
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "Built-in Speakers EQ";
            "media.name" = "Built-in Speakers EQ";
            "filter.graph" = {
              nodes = [
                {
                  type = "builtin";
                  name = "eq";
                  label = "param_eq";
                  config = {
                    filters = [
                      # High-pass sub-bass below driver roll-off to prevent cone excursion distortion
                      {
                        type = "bq_highpass";
                        freq = 95.0;
                        q = 0.707;
                        gain = 0.0;
                      }
                      # Upper-bass warmth above the 14" micro-driver cutoff
                      {
                        type = "bq_peaking";
                        freq = 160.0;
                        q = 0.9;
                        gain = 4.0;
                      }
                      # Reduce hollow aluminum-chassis low-mid boxiness
                      {
                        type = "bq_peaking";
                        freq = 420.0;
                        q = 1.4;
                        gain = -2.5;
                      }
                      # Tame tinny/nasal upper-mid resonance
                      {
                        type = "bq_peaking";
                        freq = 2400.0;
                        q = 1.3;
                        gain = -2.5;
                      }
                      # Restore vocal presence and consonant clarity
                      {
                        type = "bq_peaking";
                        freq = 5500.0;
                        q = 1.2;
                        gain = 1.5;
                      }
                      # Recover treble air lost to off-axis downward firing
                      {
                        type = "bq_highshelf";
                        freq = 10000.0;
                        q = 0.707;
                        gain = 2.5;
                      }
                    ];
                  };
                }
                {
                  type = "lv2";
                  name = "limiter";
                  plugin = "http://lsp-plug.in/plugins/lv2/limiter_stereo";
                  control = {
                    # LSP LV2 threshold uses a linear amplitude coefficient: 10^(-2.0 / 20) = -2.0 dB
                    th = 0.794328;
                    lk = 5.0; # 5 ms lookahead (0.1..20 ms)
                    at = 5.0; # 5 ms attack (0.25..20 ms)
                    rt = 10.0; # 10 ms release (0.25..20 ms)
                    alr = 0; # Pure peak protection (no program-level pumping)
                    boost = 0; # Disable default gain boost so -2.0 dB stays a true ceiling
                    ovs = 0; # No oversampling (minimal DSP CPU on battery)
                  };
                }
              ];
              links = [
                {
                  output = "eq:Out 1";
                  input = "limiter:in_l";
                }
                {
                  output = "eq:Out 2";
                  input = "limiter:in_r";
                }
              ];
              inputs = ["eq:In 1" "eq:In 2"];
              outputs = ["limiter:out_l" "limiter:out_r"];
            };
            "audio.channels" = 2;
            "audio.position" = ["FL" "FR"];
            "capture.props" = {
              "node.name" = filterNodeName;
              # Must stay exactly "Audio/Sink" even though it shows up as an extra entry in pavucontrol.
              # Hiding it as "Audio/Sink/Internal" breaks every PulseAudio client (Spotify, browsers, mpv):
              # streams are linked into the EQ, pipewire-pulse cannot resolve that node to a sink, reports
              # the stream's sink as invalid and the stream times out instead of starting.
              "media.class" = "Audio/Sink";
              "filter.smart" = true;
              "filter.smart.name" = "worknix-speaker-eq";
              # Fail-safe default until speaker-eq-route-guard confirms analog-output-speaker is active
              "filter.smart.disabled" = true;
              "filter.smart.target" = {
                "node.name" = sinkName;
              };
              "audio.channels" = 2;
              "audio.position" = ["FL" "FR"];
            };
            "playback.props" = {
              "node.name" = "effect_output.worknix_speaker_eq";
              # Allow PipeWire & snd_hda_intel to suspend normally when idle
              "node.passive" = true;
              # Never fall back to Bluetooth/HDMI/USB; wait for the analog sink if it reloads
              "node.dont-fallback" = true;
              "node.linger" = true;
              "stream.dont-remix" = true;
              "audio.channels" = 2;
              "audio.position" = ["FL" "FR"];
            };
          };
        }
      ];
    };

    /*
    Speakers and the 3.5mm headphone jack share the single SN6140 analog sink
    and switch via ALSA routes (analog-output-speaker vs analog-output-headphones).
    Toggle filter.smart.disabled in the "filters" metadata whenever the active
    output route changes so speaker EQ automatically bypasses on wired headphones.
    */
    wireplumber = {
      extraScripts."linking/speaker-eq-route-guard.lua" = ''
        local cutils = require ("common-utils")
        local log = Log.open_topic ("s-speaker-eq")

        local TARGET_DEVICE_NAME = "${cardName}"
        local SPEAKER_ROUTE_NAME = "${speakerRoute}"
        local FILTER_NODE_NAME = "${filterNodeName}"

        local last_filter_id = nil
        local last_speaker_active = nil

        local function isSpeakerRouteActive (device)
          if device == nil then
            return false
          end
          for p in device:iterate_params ("Route") do
            local route = cutils.parseParam (p, "Route")
            if route and route.direction == "Output" and route.name == SPEAKER_ROUTE_NAME then
              return true
            end
          end
          return false
        end

        SimpleEventHook {
          name = "linking/speaker-eq-route-guard",
          before = "lib/filter-utils/rescan",
          interests = {
            EventInterest {
              Constraint { "event.type", "=", "rescan-for-linking" },
            },
          },
          execute = function (event)
            local source = event:get_source ()
            local device_om = source:call ("get-object-manager", "device")
            local node_om = source:call ("get-object-manager", "node")
            local metadata_om = source:call ("get-object-manager", "metadata")

            local metadata = metadata_om:lookup {
              Constraint { "metadata.name", "=", "filters" },
            }
            local filter_node = node_om:lookup {
              Constraint { "node.name", "=", FILTER_NODE_NAME, type = "pw-global" },
            }
            if metadata == nil or filter_node == nil then
              return
            end

            local device = device_om:lookup {
              Constraint { "device.name", "=", TARGET_DEVICE_NAME, type = "pw-global" },
            }

            local filter_id = filter_node["bound-id"]
            local speaker_active = isSpeakerRouteActive (device)

            -- Only push metadata when the filter node is new or the physical output
            -- route actually changed, so manual pw-metadata A/B toggles are preserved.
            if filter_id == last_filter_id and speaker_active == last_speaker_active then
              return
            end

            last_filter_id = filter_id
            last_speaker_active = speaker_active

            local desired = speaker_active and "false" or "true"
            local current = metadata:find (filter_id, "filter.smart.disabled")
            if current ~= desired then
              log:info (string.format (
                "Setting %s (id=%d) filter.smart.disabled=%s (speaker_active=%s)",
                FILTER_NODE_NAME, filter_id, desired, tostring (speaker_active)
              ))
              metadata:set (filter_id, "filter.smart.disabled", "Spa:String:JSON", desired)
            end
          end
        }:register ()
      '';

      # Raw SPA-JSON instead of extraConfig: WirePlumber 0.5.14 keeps the quotes of
      # JSON strings in a component's `requires` array ('"metadata.filters"'), fails
      # to resolve the dependency and exits with status 78, taking all audio with it.
      configPackages = [
        (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/52-speaker-eq-route-guard.conf" ''
          wireplumber.components = [
            {
              name = linking/speaker-eq-route-guard.lua, type = script/lua
              provides = custom.speaker-eq-route-guard
              requires = [ metadata.filters ]
            }
          ]

          wireplumber.profiles = {
            main = {
              custom.speaker-eq-route-guard = required
            }
          }
        '')
      ];
    };
  };
}
