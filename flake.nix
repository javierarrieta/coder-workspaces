{
  description = "Coder workspace container images";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      packages.x86_64-linux.default = import ./image.nix { inherit pkgs; };
      packages.x86_64-linux.coder-workspaces-nix = self.packages.x86_64-linux.default;
      formatter.x86_64-linux = pkgs.nixfmt-tree;
    };
}
