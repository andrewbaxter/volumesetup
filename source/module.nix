{ config, ... }: {
  imports = [ ./moduleShared.nix ];
  config = {
    puteron.listenSystemd."local-fs.target" = true;
    puteron.listenSystemd."sockets.target" = true;
    puteron.tasks.volumesetup = {
      type = "short";
      upstream."systemd-local-fs-target" = "weak";
      # For pcscd
      upstream."systemd-sockets-target" = "weak";
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
