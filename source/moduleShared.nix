{ config, pkgs, lib, ... }: {
  options = {
    volumesetup = {
      enable = lib.mkOption {
        description = "Enable the volumesetup service to run at boot. See volumesetup documentation for default values for various parameters.";
        default = false;
        type = lib.types.bool;
      };
      debug = lib.mkOption {
        description = "Turn on debug (verbose) logging.";
        default = false;
        type = lib.types.bool;
      };
      config = lib.mkOption {
        description = "Config for volumesetup. This is directly serialized as JSON, so see the JSON config documentation. This is validated during the build for basic sanity checks.";
        default = { };
        type = lib.types.mkOptionType {
          name = "json";
          description = "Any JSON";
          check = x: true;
          merge =
            let
              uninit = "UNINIT-nix-volumesetup-task-merge";
              mergePair = { path, oldVal, newVal }:
                if oldVal == newVal then oldVal
                else if oldVal == uninit then newVal
                else if newVal == uninit then oldVal
                else if builtins.isAttrs oldVal && builtins.isAttrs newVal then
                  lib.attrsets.filterAttrs
                    (k: v: v != uninit)
                    (builtins.mapAttrs
                      (k: oldNewVal: mergePair {
                        path = path ++ [ k ];
                        oldVal = builtins.elemAt oldNewVal 0;
                        newVal = builtins.elemAt oldNewVal 1;
                      })
                      (
                        let
                          uninitSuperset =
                            lib.attrsets.genAttrs
                              (lib.lists.unique (builtins.concatLists [ (builtins.attrNames oldVal) (builtins.attrNames newVal) ]))
                              (name: uninit);
                        in
                        lib.attrsets.zipAttrs [ (uninitSuperset // oldVal) (uninitSuperset // newVal) ]
                      ))
                else builtins.throw "Conflicting values in json at ${lib.strings.concatStringsSep "." path}";
            in
            loc: defs: (builtins.foldl'
              (old: new: {
                value = mergePair {
                  path = [ ];
                  oldVal = old.value;
                  newVal = new.value;
                };
              })
              { value = uninit; }
              defs).value;
        };
      };
    };
  };
  config = {
    system.build.volumesetup.pkg = (import ./package.nix) { pkgs = pkgs; };
    system.build.volumesetup.config = pkgs.writeTextFile {
      name = "volumesetup-config";
      text = builtins.toJSON config.volumesetup.config;
      checkPhase = ''
        ${config.system.build.volumesetup.pkg}/bin/volumesetup run $out --validate
      '';
    };
  };
}
