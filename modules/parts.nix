{ inputs, ... }:

{
  # flake.modules.<class>.<name> is not built into flake-parts; this extra module declares it.
  imports = [ inputs.flake-parts.flakeModules.modules ];

  systems = [ "x86_64-linux" ];
}
