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
    authKeyFile = config.router.tailscale.authKeyFile;
    extraSetFlags = [
      "--advertise-exit-node"
      "--accept-dns=false"
    ]
    ++ (lib.optional (
      config.router.tailscale.routes != [ ]
    ) "--advertise-routes=${lib.concatStringsSep "," config.router.tailscale.routes}");
  };
}
