{ ... }@args:
{
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIcvgNOfkvVYVzwgBVc5nEUoP6Sz7WkuCIPvs4d4WyLk pecigonzalo"
    ]
    ++ (args.extraPublicKeys or [ ]);
  };

}
