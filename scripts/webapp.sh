# Launch a url as a standalone chromium app window.
url=${1:?usage: webapp <url>}
exec chromium --app="$url" --ozone-platform-hint=auto
