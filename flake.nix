{
  description = "Switchable REPL modes for zsh";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system:
          f nixpkgs.legacyPackages.${system}
        );
    in
    {
      packages = forAllSystems (pkgs: {
        default = self.packages.${pkgs.system}.zsh-modes;

        zsh-modes = pkgs.stdenvNoCC.mkDerivation {
          pname = "zsh-modes";
          version = "0.1.0";
          src = ./.;

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/zsh-modes/modes
            cp zsh-modes.plugin.zsh $out/share/zsh-modes/
            cp modes/*.zsh $out/share/zsh-modes/modes/
            cp modes/*.rb  $out/share/zsh-modes/modes/

            runHook postInstall
          '';
        };
      });

      nixosModules.default = self.nixosModules.zsh-modes;

      nixosModules.zsh-modes = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.zsh.zsh-modes;

          modeOptions = {
            ruby = {
              description = "Stateful Ruby REPL (IRB-like)";
              packages = [ pkgs.ruby ];
            };
            kubectl = {
              description = "Prepend kubectl to all commands";
              packages = [ pkgs.kubectl ];
            };
            docker = {
              description = "Prepend docker to all commands";
              packages = [ pkgs.docker-client ];
            };
            git = {
              description = "Prepend git to all commands";
              packages = [ pkgs.git ];
            };
            nix = {
              description = "Prepend nix to all commands";
              packages = [ ];
            };
          };

          plugin = self.packages.${pkgs.system}.zsh-modes;
        in
        {
          options.programs.zsh.zsh-modes = {
            enable = lib.mkEnableOption "zsh-modes plugin";

            modes = lib.mkOption {
              type = lib.types.listOf (lib.types.enum (builtins.attrNames modeOptions));
              default = builtins.attrNames modeOptions;
              description = "Which modes to enable (controls runtime dependencies)";
            };

            extraModes = lib.mkOption {
              type = lib.types.listOf lib.types.path;
              default = [ ];
              description = "Additional mode definition files to load";
            };
          };

          config = lib.mkIf cfg.enable {
            programs.zsh.enable = lib.mkDefault true;

            environment.systemPackages =
              [ plugin ] ++
              lib.pipe cfg.modes [
                (builtins.map (m: modeOptions.${m}.packages))
                builtins.concatLists
              ];

            programs.zsh.interactiveShellInit =
              let
                extraSourceLines =
                  builtins.map (f: "source ${f}") cfg.extraModes;
              in
              lib.concatStringsSep "\n" ([
                "source ${plugin}/share/zsh-modes/zsh-modes.plugin.zsh"
              ] ++ extraSourceLines);
          };
        };

      homeManagerModules.default = self.homeManagerModules.zsh-modes;

      homeManagerModules.zsh-modes = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.zsh.zsh-modes;

          modeOptions = {
            ruby = {
              description = "Stateful Ruby REPL (IRB-like)";
              packages = [ pkgs.ruby ];
            };
            kubectl = {
              description = "Prepend kubectl to all commands";
              packages = [ pkgs.kubectl ];
            };
            docker = {
              description = "Prepend docker to all commands";
              packages = [ pkgs.docker-client ];
            };
            git = {
              description = "Prepend git to all commands";
              packages = [ pkgs.git ];
            };
            nix = {
              description = "Prepend nix to all commands";
              packages = [ ];
            };
          };

          plugin = self.packages.${pkgs.system}.zsh-modes;
        in
        {
          options.programs.zsh.zsh-modes = {
            enable = lib.mkEnableOption "zsh-modes plugin";

            modes = lib.mkOption {
              type = lib.types.listOf (lib.types.enum (builtins.attrNames modeOptions));
              default = builtins.attrNames modeOptions;
              description = "Which modes to enable (controls runtime dependencies)";
            };

            extraModes = lib.mkOption {
              type = lib.types.listOf lib.types.path;
              default = [ ];
              description = "Additional mode definition files to load";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages =
              lib.pipe cfg.modes [
                (builtins.map (m: modeOptions.${m}.packages))
                builtins.concatLists
              ];

            programs.zsh.initExtra =
              let
                extraSourceLines =
                  builtins.map (f: "source ${f}") cfg.extraModes;
              in
              lib.concatStringsSep "\n" ([
                "source ${plugin}/share/zsh-modes/zsh-modes.plugin.zsh"
              ] ++ extraSourceLines);
          };
        };

      overlays.default = final: prev: {
        zsh-modes = self.packages.${final.system}.zsh-modes;
      };
    };
}
