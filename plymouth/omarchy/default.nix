# Omarchy's plymouth theme (basecamp/omarchy) with the Nix snowflake as logo.
{ runCommand, nixos-icons }:

runCommand "plymouth-omarchy-theme" { } ''
  dir=$out/share/plymouth/themes/omarchy
  mkdir -p $dir
  cp ${./.}/*.png ${./.}/omarchy.script $dir/
  cp ${nixos-icons}/share/icons/hicolor/256x256/apps/nix-snowflake.png $dir/logo.png
  substitute ${./omarchy.plymouth} $dir/omarchy.plymouth --subst-var-by themeDir $dir
''
