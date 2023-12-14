{ pkgs, lib }:

with lib;

{
  wayland.windowManager.river = {
    enable = mkEnableOption "river wayland compositor";

    package = mkOption {
      type = with types; nullOr package;
      default = pkgs.river;
      defaultText = literalExpression "${pkgs.river}";
      description = ''
        River package to use.
        Set to <code>null</code> to not add any River package to your
        path. This should be done if you want to use the NixOS River
        module to install River.
      '';
    };

    xwayland = mkOption {
      type = types.bool;
      default = true;
      description = "Enable XWayland.";
    };

    extraSessionVariables = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra session variables set when running the compositor.";
      example = { MOZ_ENABLE_WAYLAND = "1"; };
    };

    systemdIntegration = mkOption {
      type = types.bool;
      default = pkgs.stdenv.isLinux;
      example = false;
      description = ''
        Whether to enable <filename>river-session.target</filename> on
        river startup. This links to
        <filename>graphical-session.target</filename>.
        Some important environment variables will be imported to systemd
        and dbus user environment before reaching the target, including
        <itemizedlist>
        <listitem><para><literal>DISPLAY</literal></para></listitem>
        <listitem><para><literal>WAYLAND_DISPLAY</literal></para></listitem>
        <listitem><para><literal>XDG_CURRENT_DESKTOP</literal></para></listitem>
        </itemizedlist>
      '';
    };

    config = let
      mkNullOrOption = { type, description, apply ? (x: x) }:
        mkOption {
          type = types.nullOr type;
          default = null;
          inherit description apply;
        };
    in {

      # RULES
      rules = genAttrs [ "csd" "float" ] (name:
        mkOption {
          type = with types;
            listOf (submodule {
              options = {
                app_id = mkNullOrOption {
                  type = types.str;
                  description = "The app_id of the window.";
                };
                title = mkNullOrOption {
                  type = types.str;
                  description = "The title of the window.";
                };
              };
            });
          description = ''
            Add windows to the ${name} filter list based on either their app_id or title.
            Warning: Both criteria should not be provided simultaneously.
          '';
          example =
            [ { app_id = "mpv"; } { title = "popup title with spaces"; } ];
          default = [ ];
        });

      # MAPPINGS
      mappings = {
        keyboard = mkOption {
          type = with types; attrsOf (attrsOf str);
          description = "Keyboard shortcuts.";
          example = {
            normal = {
              "Alt E" = "toggle-fullscreen";
              "Alt T" = "toggle-float";
              "Alt P" = "enter-mode passthrough";
              "Alt Q" = "close";
              "Alt Return" = "spawn foot";
            };
            passthrough."Alt P" = "enter-mode normal";
            locked = {
              "None XF86AudioRaiseVolume" = "spawn 'pamixer -i 5'";
              "None XF86AudioLowerVolume" = "spawn 'pamixer -d 5'";
            };
          };
          default = { };
        };

        pointer = mkOption {
          type = with types; attrsOf (attrsOf str);
          description =
            "Mouse shortcuts. The view under the cursor will be focused.";
          example = {
            normal = {
              "Super BTN_LEFT" = "move-view";
              "Super BTN_RIGHT" = "resize-view";
              "Super BTN_MIDDLE" = "toggle-float";
              "Alt BTN_LEFT" = "move-view";
            };
          };
          default = { };
        };

        lidSwitch = mkOption {
          type = with types;
            attrsOf (submodule {
              options = {
                open = mkNullOrOption {
                  description = "Action to do when the lid is opened.";
                  type = types.str;
                };
                close = mkNullOrOption {
                  type = types.str;
                  description = "Action to do when the lid is closed.";
                };
              };
            });
          description = "Run command when river receives a lid switch event.";
          example = {
            normal = {
              open = "foo";
              close = "foo";
            };
            locked.open = "foo";
          };
          default = { };
        };

        tabletModeSwitch = mkOption {
          type = with types;
            attrsOf (submodule {
              options = {
                on = mkNullOrOption {
                  type = types.str;
                  description =
                    "Action to do when the tablet mode is activated.";
                };
                off = mkNullOrOption {
                  type = types.str;
                  description =
                    "Action to do when the tablet mode is deactivated.";
                };
              };
            });
          description =
            "Run command when river receives a tablet mode switch event.";
          example = {
            normal = {
              on = "foo";
              off = "foo";
            };
            locked.on = "foo";
          };
          default = { };
        };
      };

      # CONFIGURATION
      attachMode = mkOption {
        type = types.enum [ "top" "bottom" ];
        default = "bottom";
        description =
          "Configure where new views should attach to the view stack.";
      };

      backgroundColor = mkOption {
        type = types.str;
        default = "0x002b36";
        description = "Background color in rrggbb format.";
        example = "#ffffff";
      };

      border = {
        color = {
          focused = mkOption {
            type = types.str;
            default = "#93a1a1";
            description = "Focused border color.";
          };

          unfocused = mkOption {
            type = types.str;
            default = "#586e75";
            description = "Unfocused border color.";
          };

          urgent = mkOption {
            type = types.str;
            default = "#ff0000";
            description = "Urgent border color.";
          };
        };

        width = mkOption {
          type = types.int;
          default = 2;
          description = "Width of the border in pixels.";
        };
      };

      focusFollowsCursor = mkOption {
        type = types.enum [ "disabled" "normal" "always" ];
        default = "disabled";
        description = ''
          Whether to focus views with the mouse cursor.

          There are three available modes:
          - disabled: Moving the cursor does not affect focus. This is the default.
          - normal: Moving the cursor over a view will focus that view. Moving the cursor within a view will not re-focus that view if focus has moved elsewhere.
          - always: Moving the cursor will always focus whatever view is under the cursor.

          If the view to be focused is on an output that does not have focus, focus is switched to that output.
        '';
      };

      hideCursor = {
        timeout = mkOption {
          type = types.int;
          default = 0;
          description = ''
            Hide the cursor if it wasn't moved in the last timeout milliseconds until it is moved again.
            The default value is 0, which disables automatically hiding the cursor.
            Show the cursor again on any movement.
          '';
        };

        whenTyping = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Hide the cursor when pressing any non-modifier key.
            Show the cursor again on any movement.
          '';
        };
      };

      cursorWarp = mkOption {
        type = types.enum [ "disabled" "on-output-change" "on-focus-change" ];
        default = "disabled";
        description = ''
          Set the cursor warp mode. There are three available modes:

          - disabled: Cursor will not be warped. This is the default.
          - on-output-change: When a different output is focused, the cursor will be warped to its center.
          - on-focus-change: When a different view/output is focused, the cursor will be warped to its center.
        '';
      };

      repeatRate = mkOption {
        type = types.str;
        default = "50 300";
        description =
          "Set the keyboard repeat rate to rate key repeats per second and repeat delay to delay milliseconds.";
      };

      xCursorTheme = {
        name = mkOption {
          type = types.str;
          default = "";
          description = ''
            Set the xcursor theme.
            The theme of the default seat determines the default for Xwayland and is made
            available through the XCURSOR_THEME and XCURSOR_SIZE environment variables.
          '';
        };

        size = mkOption {
          type = with types; nullOr int;
          default = null;
          description = "Optionally set the size of the xcursor theme.";
        };
      };

      # INPUTS
      keyboard = {
        layout = mkOption {
          type = with types;
            nullOr (submodule {
              options = {
                name = mkOption {
                  type = with types; either str (listOf str);
                  description = "The name(s) of the keyboard layout(s).";
                  example = [ "us" "de" ];
                };

                rules = mkOption {
                  type = with types; nullOr (either str (listOf str));
                  description = "XKB rules.";
                  default = null;
                };

                model = mkOption {
                  type = with types; nullOr str;
                  description = "Keyboard model.";
                  default = null;
                };

                variant = mkOption {
                  type = with types; nullOr str;
                  description = "Layout variant.";
                  default = null;
                  example = "intl";
                };

                options = mkOption {
                  type = with types; nullOr (either str (listOf str));
                  description = "XKB options.";
                  default = null;
                  example = [
                    "altwin:swap_alt_win"
                    "caps:escape"
                    "grp:alt_shift_toggle"
                  ];
                };
              };
            });
          default = null;
          description = ''
            Set the XKB layout for all keyboards.
            Defaults from libxkbcommon are used for everything left unspecified.
            Note that layout may be a list of layouts which may be switched between using
            various key combinations configured through the options argument
            (e.g. -options "grp:ctrl_space_toggle").
            See xkey‐board-config(7) for possible values and more information.
          '';
        };
      };

      inputs = mkOption {
        type = with types;
          attrsOf (submodule {
            options = let
              mkNullOrBoolOption = description:
                mkNullOrOption {
                  type = types.bool;
                  inherit description;
                  apply = x:
                    if x == null then
                      null
                    else if x then
                      "enabled"
                    else
                      "disabled";
                };

              mkNullOrEnumOption = { enum, description }:
                mkNullOrOption {
                  type = types.enum enum;
                  inherit description;
                };
            in {
              events = mkNullOrEnumOption {
                enum = [ "enabled" "disabled" "disabled-on-external-mouse" ];
                description =
                  "Configure whether the input devices events will be used by river.";
              };

              accelProfile = mkNullOrEnumOption {
                enum = [ "none" "flat" "adaptive" ];
                description =
                  "Set the pointer acceleration profile of the input device.";
              };

              pointerAccel = mkNullOrOption {
                type = types.float;
                description = ''
                  Set the pointer acceleration factor of the input device.
                  Needs a float between -1.0 and 1.0.
                '';
              };

              clickMethod = mkNullOrEnumOption {
                enum = [ "none" "button-areas" "clickfinger" ];
                description = "Set the click method of the input device.";
              };

              drag = mkNullOrBoolOption
                "Enable or disable the tap-and-drag functionality of the input device.";

              dragLock = mkNullOrBoolOption
                "Enable or disable the drag lock functionality of the input device.";

              disableWhileTyping = mkNullOrBoolOption
                "Enable or disable the disable-while-typing functionality of the input device.";

              middleEmulation = mkNullOrBoolOption
                "Enable or disable the middle click emulation functionality of the input device.";

              naturalScroll = mkNullOrBoolOption
                "Enable or disable the natural scroll functionality of the input device. If active, the scroll direction is inverted.";

              leftHanded = mkNullOrBoolOption
                "Enable or disable the left handed mode of the input device.";

              tap = mkNullOrBoolOption
                "Enable or disable the tap functionality of the input device.";

              tapButtonMap = mkNullOrEnumOption {
                enum = [ "left-right-middle" "left-middle-right" ];
                description = ''
                  Configure the button mapping for tapping.
                   - left-right-middle: 1 finger tap equals left click, 2 finger tap equals right click, 3 finger tap equals middle click.
                   - left-middle-right: 1 finger tap equals left click, 2 finger tap equals middle click, 3 finger tap equals right click.
                '';
              };

              scrollMethod = mkNullOrEnumOption {
                enum = [ "none" "two-finger" "edge" "button" ];
                description = ''
                  Set the scroll method of the input device.
                   - none: No scrolling
                   - two-finger: Scroll by swiping with two fingers simultaneously
                   - edge: Scroll by swiping along the edge
                   - button: Scroll with pointer movement while holding down a button
                '';
              };

              scrollButton = mkNullOrOption {
                type = types.str;
                description =
                  "Set the scroll button of an input device. button is the name of a Linux input event code.";
              };
            };
          });
        description = ''
          Configuration rules for input devices identified by their name.
          The name of an input device consists of its type, its numerical vendor id, its numerical
          product id and finally its self-advertised name, separated by -.
        '';
        default = { };
      };

      # MISC
      layoutGenerator = {
        name = mkOption {
          type = types.str;
          default = "rivertile";
          description = "Name of the layout generator executable.";
        };

        arguments = mkOption {
          type = types.str;
          default = "";
          description = "Arguments passed to the layout generator.";
        };
      };
    };

    startupPrograms = mkOption {
      type = with types; listOf str;
      description = "Programs to be executed during startup.";
      example = [ "firefox" "foot" ];
      default = [ ];
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description =
        "Extra lines appended to <filename>$XDG_CONFIG_HOME/river/init</filename>";
    };
  };
}
