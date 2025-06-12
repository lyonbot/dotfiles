
killport() {
  lsof -i tcp:"$*" | awk 'NR!=1 {print $2}' | xargs kill -9
}

kill_node_modules() {
  PACKAGE_MANAGER="pnpm"
  if [ -f "yarn.lock" ]; then
    rm yarn.lock
    PACKAGE_MANAGER="yarn"
  fi
  if [ -f "package-lock.json" ]; then
    rm package-lock.json
    PACKAGE_MANAGER="npm"
  fi
  if [ -f "pnpm-lock.yaml" ]; then
    rm pnpm-lock.yaml
    PACKAGE_MANAGER="pnpm"
  fi

  echo "Package manager: $PACKAGE_MANAGER"
  echo "Deleting node_modules..."

  tempDir="../node_modules_to_delete_$(date +%s)"
  mv node_modules "$tempDir" && nohup rm -rf "$tempDir" &

  $PACKAGE_MANAGER install
}

gif() {
  local src="$1"
  local out="${src%.*}.gif"
  local fps=25
  local speedRatio=1
  local width="-1"
  local height="-1"

  local USAGE="Usage: gif <src> [-s speedRatio] [-f fps] [-w width] [-h height] [-o output]"
  if [ ! -f "$src" ]; then
    echo "File not found: $src"
    echo $USAGE
    return
  fi

  shift
  while [ -n "$1" ]; do
    case "$1" in
      -s) speedRatio="$2"; shift 2;;
      -f) fps="$2"; shift 2;;
      -w) width="$2"; shift 2;;
      -h) height="$2"; shift 2;;
      -o) out="$2"; shift 2;;
      *) echo $USAGE; return;;
    esac
  done

  if [ "$width" == "-1" ] && [ "$height" == "-1" ]; then
    width="iw"
    height="ih"
  fi

  ffmpeg -i "$src" \
    -filter_complex "[0:v] setpts=PTS/$speedRatio,fps=$fps,scale=w=$width:h=$height,split [a][b];[a] palettegen=stats_mode=single [p];[b][p] paletteuse=new=1" \
    -loop 0 \
    -y "$out"
}
