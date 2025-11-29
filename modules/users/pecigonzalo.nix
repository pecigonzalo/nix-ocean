{
  lib,
  pkgs,
  ...
}:
{
  users.users.pecigonzalo = {
    isNormalUser = true;
    extraGroups = lib.mkDefault [ "wheel" ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIcvgNOfkvVYVzwgBVc5nEUoP6Sz7WkuCIPvs4d4WyLk pecigonzalo"
    ];
  };

  home-manager.users.pecigonzalo = {
    home.stateVersion = "22.05";
    programs.ssh = {
      enable = true;
      compression = true;
      includes = [
        "*.config"
      ];
    };
    programs.tmux.enable = true;
    programs.fish.enable = true;
    programs.starship.enable = true;
    programs.fzf.enable = true;
  };
}
