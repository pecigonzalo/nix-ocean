{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
in
{
  imports = [
    ./nix.nix
  ];

  config = {
    # Modern OpenSSH configuration
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
        # Modern ciphers and key exchange algorithms
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
        ];
        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group16-sha512"
          "diffie-hellman-group18-sha512"
        ];
      };
      # Automatically remove stale sockets
      startWhenNeeded = false; # Always on for servers
    };

    # Firmware updates
    services.fwupd.enable = true;

    # Hardware support
    hardware.enableRedistributableFirmware = true;
  };
}
