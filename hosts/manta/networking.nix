{ config, ... }:
{
  systemd.network = {
    enable = true;
    networks = {
      "10-enp3s0" = {
        matchConfig.Name = "enp3s0";
        address = [
          "78.46.73.81/27"
          "2a01:4f8:120:4063::1/64"
        ];
        gateway = [
          "78.46.73.65"
          "fe80::1"
        ];
        dns = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };
  networking = {
    nat = {
      enable = true;
      enableIPv6 = true;
      # Change this to the interface with upstream Internet access
      externalInterface = "enp3s0";
      internalInterfaces = [ "microvm" ];
    };
    useDHCP = false;
    search = [ "hydra-micro.ts.net" ];
    nameservers = [
      "100.100.100.100"
    ];
    firewall = {
      logRefusedConnections = false;
    };
  };

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    openFirewall = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Tailscale
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
    authKeyFile = config.age.secrets.tailscale.path;
  };
}
