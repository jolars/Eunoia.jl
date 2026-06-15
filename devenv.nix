{
  pkgs,
  ...
}:

{
  packages = [
    pkgs.git
    pkgs.go-task
  ];

  languages = {
    julia = {
      enable = true;

      package = (
        pkgs.julia-bin.withPackages [
          "Aqua"
          "Artifacts"
          "Documenter"
          "GeometryBasics"
          "JSON3"
          "Libdl"
          "Makie"
          "Printf"
          "Revise"
          "Test"
        ]
      );
    };
  };
}
