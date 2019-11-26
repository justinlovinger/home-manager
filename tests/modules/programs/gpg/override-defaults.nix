{ config, lib, pkgs, ... }:

with lib;

{
  config = {
    programs.gpg = {
      enable = true;

      settings = {
        no-comments = false;
        s2k-cipher-algo = "AES128";
        throw-keyids = true;
      };

      homedir = "${config.home.homeDirectory}/bar/foopg";
    };

    nixpkgs.overlays = [
      (self: super: {
        gnupg = pkgs.writeScriptBin "dummy-gnupg" "";
      })
    ];

    nmt.script = ''
      assertFileExists home-files/bar/foopg/gpg.conf
      assertFileContent home-files/bar/foopg/gpg.conf ${./override-defaults-expected.conf}
    '';
  };
}
