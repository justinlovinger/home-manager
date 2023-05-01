{ lib, pkgs, ... }:

with lib;

{
  config = {
    wayland.windowManager.river = {
      enable = true;
      xwayland = true;
      extraSessionVariables = {
        FOO = "foo";
        BAR = "bar";
        FOURTY_TWO = 42;
      };
      systemdIntegration = true;
      config = {
        rules = {
          csd = [ { app_id = "foo"; } { app_id = "bar"; } ];
          float =
            [ { app_id = "mpd"; } { title = "popup title with spaces"; } ];
        };
        mappings = {
          keyboard = {
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
          pointer = {
            normal = {
              "Super BTN_LEFT" = "move-view";
              "Super BTN_RIGHT" = "resize-view";
              "Super BTN_MIDDLE" = "toggle-float";
              "Alt BTN_LEFT" = "move-view";
            };
          };
          lidSwitch = {
            normal = {
              open = "foo";
              close = "foo";
            };
            locked.open = "foo";
          };
          tabletModeSwitch = {
            normal = {
              on = "foo";
              off = "foo";
            };
            locked.on = "foo";
          };
        };
        attachMode = "bottom";
        backgroundColor = "#002b36";
        border = {
          color = {
            focused = "#93a1a1";
            unfocused = "#586e75";
            urgent = "#ff0000";
          };
          width = 2;
        };
        focusFollowsCursor = "normal";
        hideCursor = {
          timeout = 2;
          whenTyping = true;
        };
        cursorWarp = "on-output-change";
        repeatRate = "50 300";
        xCursorTheme = {
          name = "name";
          size = 12;
        };
        keyboard = {
          layout = {
            name = [ "us" "de" ];
            variant = "colemak";
            options =
              [ "altwin:swap_alt_win" "caps:escape" "grp:alt_shift_toggle" ];
          };
        };
        inputs = {
          pointer-foo-bar = {
            events = "enabled";
            accelProfile = "flat";
            pointerAccel = -0.3;
            tap = false;
          };
        };
        layoutGenerator = {
          name = "rivertile";
          arguments = "-view-padding 6 -outer-padding 8";
        };
      };
      startupPrograms = [ "firefox" "foot" ];
      extraConfig = ''
        some
        extra config
      '';
    };

    test.stubs.river = { };

    nmt.script = ''
      river_init=home-files/.config/river/init
      assertFileExists "$river_init"
      assertFileIsExecutable "$river_init"
      assertFileContent "$river_init" ${
        pkgs.writeShellScript "river-init-expected" (readFile ./init)
      }
    '';
  };
}
