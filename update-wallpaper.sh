#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
OUT_DIR="${HOME}/Pictures/bing-wallpapers"
MKT_PRIMARY="es-AR"       # región preferida
MKT_FALLBACK="en-US"      # fallback si falla
UHD_W=3840
UHD_H=2160

mkdir -p "$OUT_DIR"

fetch_json() {
  local mkt="$1"
  curl -Ls "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=${mkt}&uhd=1&uhdwidth=${UHD_W}&uhdheight=${UHD_H}&pid=hp"
}

# 1) Bajamos JSON
JSON="$(fetch_json "$MKT_PRIMARY" || true)"
if ! jq -e '.images[0]' >/dev/null 2>&1 <<<"$JSON"; then
  JSON="$(fetch_json "$MKT_FALLBACK")"
fi

# 2) Extraemos URL
URL_REL="$(jq -r '.images[0].url // empty' <<<"$JSON")"
if [[ -z "$URL_REL" || "$URL_REL" == "null" ]]; then
  URL_BASE="$(jq -r '.images[0].urlbase' <<<"$JSON")"
  URL_REL="${URL_BASE}_UHD.jpg&rf=LaDigue_UHD.jpg&pid=hp&w=${UHD_W}&h=${UHD_H}&rs=1&c=4"
fi
FULL_URL="https://www.bing.com${URL_REL}"

# 3) Nombre de archivo
DATE_STR="$(jq -r '.images[0].startdate' <<<"$JSON")"
TITLE="$(jq -r '.images[0].title // "bing_wallpaper"' <<<"$JSON" | tr '/|:\"?*<> ' '_' )"
FNAME="${DATE_STR}_${TITLE}.jpg"
OUT_PATH="${OUT_DIR}/${FNAME}"

# 4) Descargamos si no existe
if [[ -f "$OUT_PATH" ]]; then
  echo "Ya existe: $OUT_PATH"
else
  curl -Lso "$OUT_PATH" "$FULL_URL"
  echo "Descargado: $OUT_PATH"
fi

# 5) Mantener solo 30 últimos
ls -1t "${OUT_DIR}"/*.jpg 2>/dev/null | tail -n +31 | xargs -r rm -f

# 6) Detectar OS y aplicar wallpaper
OS="$(uname -s)"
case "$OS" in
  Darwin)
    echo "Aplicando wallpaper en macOS..."
    osascript -e "tell application \"System Events\" to set picture of every desktop to \"${OUT_PATH}\""
    ;;
  Linux)
    echo "Aplicando wallpaper en Linux..."
    if command -v gsettings >/dev/null 2>&1; then
      gsettings set org.gnome.desktop.background picture-uri "file://${OUT_PATH}"
      gsettings set org.gnome.desktop.background picture-uri-dark "file://${OUT_PATH}" || true
    elif command -v feh >/dev/null 2>&1; then
      feh --bg-fill "$OUT_PATH"
    elif command -v nitrogen >/dev/null 2>&1; then
      nitrogen --set-zoom-fill "$OUT_PATH"
    else
      echo "⚠️ No encontré comando para cambiar wallpaper en Linux. Instalá feh o usá gsettings/nitrogen."
    fi
    ;;
  *)
    echo "⚠️ Sistema operativo no soportado para cambio automático de wallpaper."
    ;;
esac

