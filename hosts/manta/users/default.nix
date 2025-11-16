{ config, pkgs, ... }: {
  imports = [
    ./pecigonzalo.nix
  ];

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
  programs.ssh = {
    startAgent = true;
  };
  users = rec {
    mutableUsers = false;
    groups.media = {
      name = "media";
      gid = 995;
    };
    groups.wordpress = {
      name = "wordpress";
      gid = 996;
    };

    users = {
      root.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIcvgNOfkvVYVzwgBVc5nEUoP6Sz7WkuCIPvs4d4WyLk pecigonzalo"
      ];
      media = {
        uid = 995;
        isSystemUser = true;
        group = groups.media.name;
      };
      wordpress = {
        uid = 996;
        isSystemUser = true;
        group = groups.wordpress.name;
      };
    };
  };
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
}
