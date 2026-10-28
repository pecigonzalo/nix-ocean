{
  ...
}:
{
  imports = [
    ./nix.nix
  ];

  config = {
    # Servers stay on UTC, but declare it: with the default (`null`) no
    # /etc/localtime is generated and systemd reports "Time zone: n/a", which
    # is how a stray Docker-created /etc/localtime directory went unnoticed.
    time.timeZone = "UTC";

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
          "mlkem768x25519-sha256"
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
