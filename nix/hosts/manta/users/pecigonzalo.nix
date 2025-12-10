{ config, ... }:
{
  imports = [
    ../../../modules/users/pecigonzalo.nix
  ];

  users.users.pecigonzalo.extraGroups =
    [
      "wheel"
      "docker"
      config.users.groups.media.name
      config.users.groups.wordpress.name
    ];
}
