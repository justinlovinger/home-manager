{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.wayland.windowManager.river;

  # RULES
  rules = let
    mkRulesList = listName:
      map (criteria:
        let
          rule = if (criteria.app_id != null) then
            ''app-id "${criteria.app_id}"''
          else
            ''title "${criteria.title}"'';
        in ''
          riverctl ${listName}-filter-add ${rule}
        '') cfg.config.rules.${listName};

    csdRules = mkRulesList "csd";
    floatRules = mkRulesList "float";

    rulesList = csdRules ++ floatRules;

  in concatStrings rulesList;

  # MAPPINGS
  declareModes = let
    # [ "normal" "passthrough" "locked" ... ]
    allModes = lists.unique
      (lists.flatten (mapAttrsToList (n: v: attrNames v) cfg.config.mappings));

  in concatStringsSep "\n"
  (map (mode: "riverctl declare-mode ${mode}") allModes);

  keyboardMappingsStr = let
    genKeyboardMapping = mode: mappings:
      mapAttrsToList (key: command: "riverctl map ${mode} ${key} ${command}")
      mappings;

    keyboardMappings = lists.flatten
      (mapAttrsToList genKeyboardMapping cfg.config.mappings.keyboard);

  in concatStringsSep "\n" keyboardMappings;

  pointerMappingsStr = let
    genPointerMapping = mode: mappings:
      mapAttrsToList
      (button: command: "riverctl map-pointer ${mode} ${button} ${command}")
      mappings;
    pointerMappings = lists.flatten
      (mapAttrsToList genPointerMapping cfg.config.mappings.pointer);
  in concatStringsSep "\n" pointerMappings;

  switchMappings = let
    mkSwitchMapping = { mode, device, state, command }: ''
      riverctl map-switch ${mode} ${device} ${state} ${command}
    '';

    mkSwitchMappings = mode: mappings:
      mapAttrsToList (state: command:
        optionalString (command != null) (mkSwitchMapping {
          device = "lid";
          inherit mode state command;
        })) mappings;

    lidSwitchMappings = concatStrings (lists.flatten
      (mapAttrsToList mkSwitchMappings cfg.config.mappings.lidSwitch));

    tabletModeSwitchMappings = concatStrings (lists.flatten
      (mapAttrsToList mkSwitchMappings cfg.config.mappings.lidSwitch));

  in ''
    # Switch mappings
  '' + lidSwitchMappings + tabletModeSwitchMappings;

  mappings = ''
    # Declare modes
    ${declareModes}

    # Keyboard mappings
    ${keyboardMappingsStr}

    # Pointer mappings
    ${pointerMappingsStr}

    ${switchMappings}
  '';

  # INPUTS
  keyboardLayout = let
    keyboardLayoutOption = cfg.config.keyboard.layout;

    name = if isList keyboardLayoutOption.name then
      ''"${concatStringsSep "," keyboardLayoutOption.name}"''
    else
      keyboardLayoutOption.name;

    mkArg = optionName:
      let
        rawArgValue = keyboardLayoutOption.${optionName};
        argValue = if isList rawArgValue then
          concatStringsSep "," rawArgValue
        else
          rawArgValue;
      in optionalString (argValue != null) ''-${optionName} "${argValue}"'';

    args =
      concatStringsSep " " (map mkArg [ "rules" "model" "variant" "options" ]);
  in optionalString (keyboardLayoutOption != null)
  "riverctl keyboard-layout ${args} ${name}";

  inputsSettings = let
    inputSettings = mapAttrsToList (inputName: inputConfig:
      mapAttrsToList (option: value:
        let
          # fooBarOption -> foo-bar-option
          formatOptionName =
            builtins.replaceStrings upperChars (map (c: "-${c}") lowerChars);

        in "riverctl input ${inputName} ${formatOptionName option} ${
          toString value
        }") (filterAttrs (n: v: v != null) inputConfig)) cfg.config.inputs;
  in concatStringsSep "\n" (lists.flatten inputSettings);

  inputs = ''
    ${keyboardLayout}

    ${inputsSettings}
  '';

  # CONFIGURATION
  convertColor = colorString: "0x${replaceStrings [ "#" ] [ "" ] colorString}";
  xCursorTheme = let
    themeName = cfg.config.xCursorTheme.name;
    size = cfg.config.xCursorTheme.size;
  in optionalString (themeName != "") "riverctl xcursor-theme ${themeName}${
    optionalString (size != null) " ${toString size}"
  }";

  configuration = ''
    riverctl attach-mode ${cfg.config.attachMode}
    riverctl background-color ${convertColor cfg.config.backgroundColor}
    riverctl border-color-focused ${
      convertColor cfg.config.border.color.focused
    }
    riverctl border-color-unfocused ${
      convertColor cfg.config.border.color.unfocused
    }
    riverctl border-color-urgent ${convertColor cfg.config.border.color.urgent}
    riverctl border-width ${toString cfg.config.border.width}
    riverctl focus-follows-cursor ${cfg.config.focusFollowsCursor}
    riverctl hide-cursor timeout ${toString cfg.config.hideCursor.timeout}
    riverctl hide-cursor timeout ${
      if cfg.config.hideCursor.whenTyping then "enabled" else "disabled"
    }
    riverctl set-cursor-warp ${cfg.config.cursorWarp}
    riverctl set-repeat ${cfg.config.repeatRate}
    ${xCursorTheme}
  '';

  formatStartupProgram = command: ''riverctl spawn "${command}"'';

in {
  meta.maintainers = [ maintainers.GaetanLepage ];

  options = import ./options.nix { inherit pkgs lib; };

  config = mkIf cfg.enable {
    assertions = [
      (hm.assertions.assertPlatform "wayland.windowManager.river" pkgs
        platforms.linux)
    ];

    home.packages = optional (cfg.package != null) cfg.package
      ++ optional cfg.xwayland pkgs.xwayland;

    xdg.configFile."river/init".source = pkgs.writeShellScript "init" ''
      ### This file was generated with Nix. Don't modify this file directly.

      ### SHELL VARIABLES ###
      ${config.lib.shell.exportAll cfg.extraSessionVariables}

      ### RULES ###
      ${rules}

      ### MAPPINGS ###
      ${mappings}

      ### CONFIGURATION ###
      ${configuration}

      ### INPUTS ###
      ${inputs}

      ### EXTRA CONFIGURATION ###
      ${cfg.extraConfig}

      ### STARTUP PROGRAMS ###
      ${concatMapStringsSep "\n" formatStartupProgram cfg.startupPrograms}

      ### LAYOUT ###
      riverctl default-layout ${cfg.config.layoutGenerator.name}
      ${cfg.config.layoutGenerator.name} ${cfg.config.layoutGenerator.arguments} &
    '';

    systemd.user.targets.river-session = mkIf cfg.systemdIntegration {
      Unit = {
        Description = "river compositor session";
        Documentation = [ "man:systemd.special(7)" ];
        BindsTo = [ "graphical-session.target" ];
        Wants = [ "graphical-session-pre.target" ];
        After = [ "graphical-session-pre.target" ];
      };
    };

    systemd.user.targets.tray = {
      Unit = {
        Description = "Home Manager System Tray";
        Requires = [ "graphical-session-pre.target" ];
      };
    };
  };
}
