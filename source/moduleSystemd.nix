{ config, ... }: {
  imports = [ ./moduleShared.nix ];
  config = {
    systemd.services = {
      volumesetup = {
        wantedBy = [ "local-fs.target" ];
        after = [
          "local-fs.target"
          # For pcscd
          "sockets.target"
        ];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = "yes";
        startLimitIntervalSec = 0;
        serviceConfig.Restart = "on-failure";
        serviceConfig.RestartSec = 60;
        script =
          let
            debug = if config.volumesetup.debug then "--debug" else "";
          in
          "${config.system.build.volumesetup.pkg}/bin/volumesetup run ${config.system.build.volumesetup.config} ${debug}";
      };
    };
  };
}
