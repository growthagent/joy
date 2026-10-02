{
  description = "joy-fullstack";

  nixConfig = {
    extra-substituters = [ "https://niclas-ahden.cachix.org" ];
    extra-trusted-public-keys = [ "niclas-ahden.cachix.org-1:FdGli1vBk0cTuVJV27Tau/JvlbW+Ly3pRwFByyqdke0=" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # Roc compiler revision, keep the `?dir=src` at the end.
    roc-src.url = "github:roc-lang/roc/b797cda76e77b9e514c2192ca6513d0ba9a39070?dir=src";
    roc-nix = {
      url = "github:niclas-ahden/roc-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.roc-src.follows = "roc-src";
    };
  };

  outputs = { nixpkgs, flake-utils, roc-nix, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Builds Roc using `ReleaseFast`. To chase a suspected compiler fault,
        # build a `ReleaseSafe` variant of the same revision:
        #
        #   roc-nix.lib.${system}.mkRoc { optimize = "ReleaseSafe"; }
        #
        # roc-nix's README lists the rest of the build options, patches
        # included.
        roc = roc-nix.packages.${system}.roc;
      in
      {
        formatter = pkgs.nixpkgs-fmt;

        packages = {
          inherit roc;
          default = roc;
        };

        devShells =
          let
            testTools = [
              pkgs.playwright-test # drives the browser during ./e2e.roc
            ];
            playwrightHook = ''
              export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
              export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
            '';
          in
          {
            default = pkgs.mkShell {
              buildInputs = [ roc ] ++ testTools;
              shellHook = playwrightHook;
            };

            # Everything ./e2e.roc needs except roc itself, for runs
            # against another compiler, like the nightly workflow. Prebuilt
            # in the public Nix cache, so no compiler builds here.
            tests = pkgs.mkShell {
              buildInputs = testTools;
              shellHook = playwrightHook;
            };
          };
      });
}
