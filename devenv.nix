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
    rust = {
      enable = true;

      channel = "stable";
    };

    julia = {
      enable = true;

      package = (
        pkgs.julia-bin.withPackages [
          "Aqua"
          "Artifacts"
          "ArtifactUtils"
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
