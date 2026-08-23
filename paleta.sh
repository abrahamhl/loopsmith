#!/usr/bin/env bash
# paleta.sh — Extrae la paleta de una imagen o video de referencia y la traduce
# a lenguaje de prompt.
#
# Sirve para usar una referencia de color SIN pasarle la imagen al generador,
# que es lo que hace que se cuele el contenido que no quieres (personas, objetos).
#
#   ./paleta.sh referencia.jpg
#   ./paleta.sh referencia.mp4
#
# Separa ACENTOS (los saturados que definen el look) de TONOS BASE (el suelo
# tonal que ocupa area). En una imagen nocturna los acentos son el 5% de los
# pixeles pero el 90% del caracter visual: sin esta separacion la paleta sale
# en gris y no sirve para nada.
#
# Requiere ffmpeg en el PATH.

set -euo pipefail

SRC="${1:-}"
if [[ -z "$SRC" || ! -f "$SRC" ]]; then
  echo "uso: ./paleta.sh <imagen-o-video>" >&2
  exit 1
fi
command -v ffmpeg >/dev/null || { echo "falta ffmpeg en el PATH" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

STILL="$SRC"
case "${SRC,,}" in
  *.mp4|*.mov|*.mkv|*.webm|*.avi)
    ffmpeg -v error -i "$SRC" -vf "fps=1,scale=320:-1" -frames:v 30 "$TMP/f_%03d.png"
    ffmpeg -v error -pattern_type glob -i "$TMP/f_*.png" \
      -vf "palettegen=max_colors=32:stats_mode=full:reserve_transparent=0" -y "$TMP/pal.png"
    STILL="$TMP/f_001.png" ;;
  *)
    ffmpeg -v error -i "$SRC" \
      -vf "palettegen=max_colors=32:stats_mode=full:reserve_transparent=0" -y "$TMP/pal.png" ;;
esac

rgbdump() { ffmpeg -v error -i "$1" -vf "$2" -f rawvideo -pix_fmt rgb24 - \
  | od -An -tx1 -v | tr -s ' ' '\n' | grep -v '^$' | paste - - - | tr -d '\t' | awk '!seen[$0]++'; }

# ACENTOS: del conjunto cuantizado, los mas vividos.
rgbdump "$TMP/pal.png" "null" > "$TMP/acc.txt"
# TONOS BASE: promedio por areas — refleja cuanta superficie ocupa cada tono.
rgbdump "$STILL" "scale=4:3:flags=area" > "$TMP/base.txt"

cat > "$TMP/pal.awk" <<'AWK'
function hsv(r,g,b) {
  mx = (r>g ? (r>b?r:b) : (g>b?g:b)); mn = (r<g ? (r<b?r:b) : (g<b?g:b)); d = mx-mn
  V = mx/255; S = (mx==0 ? 0 : d/mx)
  if (d==0)       H = 0
  else if (mx==r) H = 60*((((g-b)/d)%6+6)%6)
  else if (mx==g) H = 60*(((b-r)/d)+2)
  else            H = 60*(((r-g)/d)+4)
}
function name(r,g,b,   base,mod) {
  hsv(r,g,b)
  if (V < 0.10) return "near-black"
  if (S < 0.12) return (V<0.35 ? "dark grey" : (V<0.75 ? "mid grey" : "off-white"))
  if      (H<15 || H>=345) base="red"
  else if (H<45)  base="orange"
  else if (H<70)  base="amber"
  else if (H<160) base="green"
  else if (H<195) base="cyan"
  else if (H<232) base="blue"
  else if (H<290) base="violet"
  else            base="magenta"
  if      (V < 0.38)             mod="deep "
  else if (S > 0.70 && V > 0.70) mod="neon "
  else if (S < 0.40)             mod="muted "
  else if (V > 0.85)             mod="bright "
  else                           mod=""
  return mod base
}
function emit(hx,r,g,b,   n) { n=name(r,g,b)
  printf "  #%s   %-14s  rgb(%3d,%3d,%3d)\n", toupper(hx), n, r, g, b > "/dev/stderr"
  return n }
{
  hx=$0
  r = strtonum("0x" substr(hx,1,2)); g = strtonum("0x" substr(hx,3,2)); b = strtonum("0x" substr(hx,5,2))
  hsv(r,g,b)
  c++; HX[c]=hx; R[c]=r; G[c]=g; B[c]=b; VIV[c]= S * (V<0.9?V:0.9); N[c]=name(r,g,b)
}
END {
  for (i=1;i<=c;i++) ix[i]=i
  for (i=1;i<c;i++) for (j=i+1;j<=c;j++) if (VIV[ix[j]]>VIV[ix[i]]) { t=ix[i]; ix[i]=ix[j]; ix[j]=t }
  lim = (MODE=="acc" ? 4 : 3)
  k=0
  for (q=1; q<=c && k<lim; q++) {
    i = (MODE=="acc" ? ix[q] : ix[c-q+1])
    if (MODE=="acc" && VIV[i] < 0.06) break
    dup=0; for (z=1;z<=k;z++) if (seen[z]==N[i]) dup=1
    if (dup) continue
    k++; seen[k]=N[i]
    printf "  #%s   %-14s  rgb(%3d,%3d,%3d)\n", toupper(HX[i]), N[i], R[i], G[i], B[i]
    out = out (k>1 ? ", " : "") N[i]
  }
  if (k==0) { print "  (ninguno)"; out="neutral" }
  print "PHRASE:" out > "/dev/stderr"
}
AWK

run() { awk -v MODE="$1" -f "$TMP/pal.awk" "$2" 2>"$TMP/ph_$1"; }

echo
echo "PALETA — $(basename "$SRC")"
echo "============================================================"
echo "ACENTOS  (definen el look — son los que van al prompt)"
run acc  "$TMP/acc.txt"
echo
echo "TONOS BASE  (el suelo tonal, por superficie ocupada)"
run base "$TMP/base.txt"
ACC=$(sed 's/^PHRASE://' "$TMP/ph_acc")
BAS=$(sed 's/^PHRASE://' "$TMP/ph_base")
echo "============================================================"
echo
echo "PARA PEGAR EN EL PROMPT:"
echo
echo "  Colour palette: ${ACC} accents over a ${BAS} base."
echo
echo "Usa esto EN VEZ de pasar la imagen de referencia al generador:"
echo "consigues el color sin que se cuele el contenido de la referencia."
echo
