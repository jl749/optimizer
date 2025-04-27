{
  description = "PYTHON ENV";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    pythonEnv = pkgs.python312.withPackages (ps: with ps; [
      onnx
      cmake
      setuptools
      distutils
      mypy
      pybind11
    ]);
  in {
    devShells.${system}.onnx = 
      pkgs.mkShell {
        nativeBuildInputs = [];
        buildInputs = with pkgs; [
          pythonEnv
        ];
        packages = [];
        shellHook = ''
          python3 -V
        '';
      };
  };
}
        
