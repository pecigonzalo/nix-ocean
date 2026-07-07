{
  pkgs,
  config,
  lib,
  ...
}:
let
  tailscaleFlags =
    [
      "--advertise-exit-node"
      "--accept-dns=false"
    ]
    ++ lib.optional (
      config.router.tailscale.routes != [ ]
    ) "--advertise-routes=${lib.concatStringsSep "," config.router.tailscale.routes}";
in
{
  environment.systemPackages = [ pkgs.tailscale ];

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    authKeyFile = config.router.tailscale.authKeyFile;
    extraUpFlags = tailscaleFlags;
    extraSetFlags = tailscaleFlags;
  };
}
