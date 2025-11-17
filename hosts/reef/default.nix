# Common configuration for all reef cluster nodes
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../modules/common/disko.nix
    ../../modules/common/base.nix
    ../../modules/common/performance.nix
    ../../modules/common/users.nix
    ../../modules/roles/n150.nix
    ../../modules/roles/reefNode.nix
  ];
}
