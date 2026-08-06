{ ... }:
{
  xdg.desktopEntries.nvim = {
    name = "Neovim";
    genericName = "Text Editor";
    exec = "term -e nvim %F";
    terminal = false;
    type = "Application";
    icon = "nvim";
    categories = [ "Utility" "TextEditor" ];
    mimeType = [ "text/plain" ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "inode/directory" = "thunar.desktop";
      "text/plain" = "nvim.desktop";
      "text/markdown" = "nvim.desktop";
      "application/json" = "nvim.desktop";
      "application/xml" = "nvim.desktop";
      "text/x-shellscript" = "nvim.desktop";
      "text/x-python" = "nvim.desktop";
      "application/zip" = "engrampa.desktop";
      "application/x-7z-compressed" = "engrampa.desktop";
      "application/vnd.rar" = "engrampa.desktop";
      "application/x-tar" = "engrampa.desktop";
      "application/x-compressed-tar" = "engrampa.desktop";
      "application/x-xz-compressed-tar" = "engrampa.desktop";
      "text/html" = "zen-beta.desktop";
      "application/xhtml+xml" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/about" = "zen-beta.desktop";
      "x-scheme-handler/unknown" = "zen-beta.desktop";
      "image/png" = "imv-dir.desktop";
      "image/jpeg" = "imv-dir.desktop";
      "image/gif" = "imv-dir.desktop";
      "image/webp" = "imv-dir.desktop";
      "image/bmp" = "imv-dir.desktop";
      "image/tiff" = "imv-dir.desktop";
      "image/svg+xml" = "imv-dir.desktop";
      "image/avif" = "imv-dir.desktop";
      "image/heif" = "imv-dir.desktop";
      "video/mp4" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";
      "video/mpeg" = "mpv.desktop";
    };
  };
}
