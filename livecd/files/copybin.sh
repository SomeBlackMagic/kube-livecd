copybin() {
  b="$(command -v "$1")"
  install -D "$b" "/initrd/bin/$(basename "$b")"
  ldd "$b" | awk '{ if ($2=="=>") print $3; else if ($1 ~ /^\//) print $1 }' \
    | xargs -r -I{} install -D "{}" "/initrd{}"
}
