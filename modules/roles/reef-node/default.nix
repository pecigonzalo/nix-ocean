{
  pkgs,
  config,
  lib,
  ...
}:
{
  options = {
    reefNode = {
      lan = {
        mac = lib.mkOption {
          type = lib.types.str;
          description = "LAN interface MAC address";
        };
        address = lib.mkOption {
          type = lib.types.str;
          description = "LAN IP address";
        };
        prefixLength = lib.mkOption {
          type = lib.types.int;
          default = 24;
          description = "LAN prefix length";
        };
        defaultGateway = lib.mkOption {
          type = lib.types.str;
          description = "LAN default gateway";
        };
        nameserver = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "LAN nameserver";
        };
      };
    };
  };
  config = {
    systemd.network.links."10-lan" = {
      matchConfig.PermanentMACAddress = config.reefNode.lan.mac;
      linkConfig.Name = "lan";
    };

    networking = {
      networkmanager.enable = true;
      networkmanager.wifi.backend = "iwd";

      interfaces.lan.ipv4.addresses = [
        {
          address = config.reefNode.lan.address;
          prefixLength = config.reefNode.lan.prefixLength;
        }
      ];
      defaultGateway = config.reefNode.lan.defaultGateway;
      nameservers = config.reefNode.lan.nameserver;

      firewall = {
        enable = true;
        checkReversePath = "loose"; # Allow asymmetric routing
        trustedInterfaces = [
          "lan"
          "wlan0"
        ];
        allowedTCPPorts = [ 22 ];
        allowPing = true;
      };
    };

    # Fix for dual-homing on same subnet (lan + wlan0)
    boot.kernel.sysctl = {
      # Ensure wlan0 responds with correct source IP in ARP
      "net.ipv4.conf.wlan0.arp_announce" = 2;
      "net.ipv4.conf.wlan0.arp_ignore" = 1;
    };

    # Policy routing: ensure replies from wlan0 IP exit via wlan0
    networking.localCommands = ''
      # Wait for wlan0 to get IP via DHCP
      for i in {1..30}; do
        WLAN_IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        [ -n "$WLAN_IP" ] && break
        sleep 1
      done
      
      if [ -n "$WLAN_IP" ]; then
        # Use a custom routing table that prefers wlan0's default route
        ip rule add from $WLAN_IP table 100 priority 100 2>/dev/null || true
        # Copy wlan0's routes to table 100
        ip route show dev wlan0 | while read route; do
          ip route add $route table 100 2>/dev/null || true
        done
        ip route flush cache
      fi
    '';

    # Ensure WiFi auto-connects on boot
    networking.networkmanager.ensureProfiles.profiles = {
      wifi-failover = {
        connection = {
          id = "wifi-failover";
          type = "wifi";
          interface-name = "wlan0";
          autoconnect = true;
        };
        wifi = {
          mode = "infrastructure";
          ssid = "DavyJones IoT";
        };
        ipv4 = {
          method = "auto"; # DHCP
        };
        ipv6 = {
          method = "disabled";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          # Password must be set manually once via: nmcli connection modify wifi-failover wifi-sec.psk '<your-password>'
          # It persists in /etc/NetworkManager/system-connections/
        };
      };
    };

    environment.systemPackages = [ pkgs.tailscale ];
  };
}
