# Launch a url as a standalone helium app window.
url=${1:?usage: webapp <url>}
exec helium --app="$url" --ozone-platform-hint=auto
