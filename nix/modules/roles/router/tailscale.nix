{
  pkgs,
  config,
  lib,
  ...
}:
{
  environment.systemPackages = [ pkgs.tailscale ];

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    extraSetFlags = [
      "--advertise-exit-node"
      "--accept-dns=false"
    ]
    ++ (lib.optional (
      config.router.tailscale.routes != [ ]
    ) "--advertise-routes=${lib.concatStringsSep "," config.router.tailscale.routes}");
  };

  systemd.services.tailscaled-autoconnect = {
    description = "Automatic connection to Tailscale";
    after = [
      "network-pre.target"
      "tailscaled.service"
    ];
    wants = [
      "network-pre.target"
      "tailscaled.service"
    ];
    before = [ "tailscaled-set.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";

    script = with pkgs; ''
      sleep 2

      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ "$status" = "Running" ]; then
        echo "Tailscale is already configured correctly, skipping."
        exit 0
      fi

      AUTHKEY="$(cat ${config.router.tailscale.authKeyFile})"

      echo "Tailscale is running but not fully configured, will reconfigure..."
      ${tailscale}/bin/tailscale up --authkey "$AUTHKEY" ${lib.concatStringsSep " " config.services.tailscale.extraSetFlags} || {
        echo "Failed to connect. If auth key expired, update config with new key or use 'tailscale up' manually."
        exit 1
      }
    '';
  };
}
