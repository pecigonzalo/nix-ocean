{ ... }: {
  containers = {
    # k3s = {
    #   autoStart = true;
    #
    #   extraFlags = [ "-U" ];
    #
    #   privateNetwork = true;
    #   hostAddress = "10.0.0.1";
    #   localAddress = "10.0.0.10";
    #
    #   config = { config, pkgs, lib, ... }: {
    #     system.stateVersion = config.system.nixos.version;
    #     services.k3s = {
    #       enable = true;
    #       role = "server";
    #     };
    #     networking = {
    #       firewall = {
    #         enable = true;
    #         allowedTCPPorts = [ 6443 ];
    #       };
    #     };
    #     # Use systemd-resolved inside the container
    #     # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
    #     networking.useHostResolvConf = lib.mkForce false;
    #     services.resolved.enable = true;
    #   };
    # };
  };
}

