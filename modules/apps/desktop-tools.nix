{
  flake.modules.homeManager.metsker = { pkgs, ... }: {
    home.packages = with pkgs; [
      (writeShellApplication {
        name = "screenshot";
        runtimeInputs = [ grim slurp satty wayfreeze wlrctl libnotify ];
        text = builtins.readFile ../scripts/screenshot.sh;
      })
      # wayfreeze gives the instant freeze; hyprpicker picks with its zoom lens.
      (writeShellApplication {
        name = "colorpicker";
        runtimeInputs = [ wayfreeze hyprpicker ];
        text = builtins.readFile ../scripts/colorpicker.sh;
      })
      # Freeze, slurp a region, OCR it with tesseract, copy the text to the clipboard.
      (writeShellApplication {
        name = "textpicker";
        runtimeInputs = [ wayfreeze slurp grim wlrctl tesseract wl-clipboard libnotify ];
        text = builtins.readFile ../scripts/textpicker.sh;
      })
      # Super+C/V copy/paste: mmsg (mango) reads the focused appid, wtype injects Ctrl(+Shift)+C/V.
      (writeShellApplication {
        name = "clipboard";
        runtimeInputs = [ wtype jq mangowm ];
        text = builtins.readFile ../scripts/clipboard.sh;
      })

      hyprpicker
      slurp
      wl-clipboard
      libnotify
    ];
  };
}
