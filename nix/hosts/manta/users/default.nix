{ ... }:
{
  imports = [
    ../../../modules/common/users.nix
    ./pecigonzalo.nix
  ];

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  programs.ssh.startAgent = true;

  users = {
    mutableUsers = false;

    groups.media = {
      name = "media";
      gid = 995;
    };
    groups.wordpress = {
      name = "wordpress";
      gid = 996;
    };

    users.media = {
      uid = 995;
      isSystemUser = true;
      group = "media";
    };

    users.wordpress = {
      uid = 996;
      isSystemUser = true;
      group = "wordpress";
    };
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
}
