{ config, ... }: {
  imports = [ ./moduleShared.nix ];
  config = {
    puteron.tasks.volumesetup = {
      type = "short";
      command = {
        line = [
          "${config.system.build.volumesetup.pkg}/bin/volumesetup"
          "run"
          "${config.system.build.volumesetup.config}"
        ]
        ++ (if config.volumesetup.debug then [ "--debug" ] else [ ])
        ++ [ ];
      };
    };
  };
}
