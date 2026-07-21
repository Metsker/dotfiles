# Launch a url as a standalone chromium app window with a stable app-id.
id=${1:?usage: webapp <app-id> <url>}
url=${2:?usage: webapp <app-id> <url>}
exec chromium --app="$url" --class="$id" --ozone-platform-hint=auto
