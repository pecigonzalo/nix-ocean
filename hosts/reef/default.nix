# Common configuration for all reef cluster nodes
# reef: Reef cluste nodes
# hardware: Intel N150, 12GB, 512GB SSD
{ ... }:
{
  imports = [
    ../../modules/common/base.nix
    ../../modules/common/performance.nix
    ../../modules/common/server-tools.nix
    ../../modules/common/users.nix
    ../../modules/roles/n150
    ../../modules/roles/reef-node
  ];
}
