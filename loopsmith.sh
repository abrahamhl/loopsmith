#!/usr/bin/env bash
# loopsmith.sh — Monta N clips de video generativo en un bucle de duracion EXACTA,
# eligiendo automaticamente los puntos de corte que minimizan el error de costura.
#
#   ./loopsmith.sh --out salida.mp4 tirada-1.mp4 tirada-2.mp4
#   ./loopsmith.sh --duration 20 --dry-run a.mp4 b.mp4
#
# EL PROBLEMA QUE RESUELVE
# Kling, Runway, Veo y Sora no entregan duraciones exactas ni bucles limpios:
#  - una tirada de "15 s" son 15,041667 s (361 frames a 24 fps), no 15,000
#  - el primer frame de cada tirada es el still de entrada recodificado, con
#    textura distinta al resto
#  - el ultimo frame "arrastra": el modelo aterriza sobre el end-frame y se
#    mueve menos que sus vecinos
# Concatenar sin mas deja un tiron visible en cada costura y una duracion rota.
#
# COMO LO RESUELVE
# Mide la energia de movimiento real de cada costura candidata y elige la
# combinacion de recortes que (a) da la duracion exacta pedida y (b) deja cada
# costura lo mas parecida posible a un paso de frame normal.
# El objetivo no es minimizar la diferencia: es acercarla a 1,0. Un paso
# demasiado GRANDE es un salto; uno demasiado PEQUENO es un congelado.
# Los dos se ven, y por eso se penalizan igual.
#
# Requiere ffmpeg y ffprobe en el PATH.

set -euo pipefail

OUT="loop.mp4"; DUR=30; FPS=""; SIZE="1920x1080"; CRF=15; DRY=0; LOOP=1; MAXDROP=3; MOTION=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)      OUT="$2"; shift 2 ;;
    --duration) DUR="$2"; shift 2 ;;
    --fps)      FPS="$2"; shift 2 ;;
    --size)     SIZE="$2"; shift 2 ;;
    --crf)      CRF="$2"; shift 2 ;;
    --dry-run)  DRY=1; shift ;;
    --no-loop)  LOOP=0; shift ;;
    --motion-cut) MOTION=1; shift ;;
    -h|--help)  sed -n '2,30p' "$0"; exit 0 ;;
    -*)         echo "opcion desconocida: $1" >&2; exit 1 ;;
    *)          CLIPS+=("$1"); shift ;;
  esac
done

CLIPS=("${CLIPS[@]:-}")
[[ -z "${CLIPS[0]:-}" ]] && { echo "uso: ./loopsmith.sh [opciones] clip1.mp4 clip2.mp4 ..." >&2; exit 1; }
NC=${#CLIPS[@]}
for c in "${CLIPS[@]}"; do [[ -f "$c" ]] || { echo "no existe: $c" >&2; exit 1; }; done
command -v ffmpeg >/dev/null && command -v ffprobe >/dev/null || { echo "falta ffmpeg/ffprobe" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
OW="${SIZE%x*}"; OH="${SIZE#*x}"

echo
echo "LOOPSMITH"
echo "=================================================================="

# ── 1. Sondeo ─────────────────────────────────────────────────────────
declare -a NF SW SH
TOTAL=0
for i in $(seq 0 $((NC-1))); do
  c="${CLIPS[$i]}"
  read -r w h rfr < <(ffprobe -v error -select_streams v \
      -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$c" | tr ',' ' ')
  n=$(ffprobe -v error -select_streams v -count_frames \
      -show_entries stream=nb_read_frames -of csv=p=0 "$c")
  [[ -z "$FPS" ]] && FPS=$(awk -F/ '{printf "%d", ($2?$1/$2:$1)}' <<<"$rfr")
  NF[$i]=$n; SW[$i]=$w; SH[$i]=$h; TOTAL=$((TOTAL+n))
  printf "  clip %d  %-38s %5d frames  %dx%d\n" $((i+1)) "$(basename "$c")" "$n" "$w" "$h"
done

TARGET=$(awk -v d="$DUR" -v f="$FPS" 'BEGIN{printf "%d", d*f}')
DROP=$((TOTAL-TARGET))
echo "  ----------------------------------------------------------------"
printf "  disponibles %d frames | objetivo %d (%s s a %s fps) | sobran %d\n" \
       "$TOTAL" "$TARGET" "$DUR" "$FPS" "$DROP"

if (( DROP < 0 )); then
  echo; echo "  ERROR: faltan $((-DROP)) frames para llegar a ${DUR}s." >&2
  echo "  Genera mas material o baja --duration." >&2; exit 1
fi

# Posiciones de recorte: cabeza de cada clip salvo el primero, + cola del ultimo si hay bucle.
NPOS=$((NC-1)); (( LOOP )) && NPOS=$((NPOS+1))
if (( DROP > NPOS*MAXDROP )); then
  echo; echo "  ERROR: hay que quitar $DROP frames y solo puedo tocar $((NPOS*MAXDROP))" >&2
  echo "  sin deformar el material. Ajusta --duration." >&2; exit 1
fi

# ── 2. Extraccion de frontera ─────────────────────────────────────────
ext() { ffmpeg -v error -y -i "$1" -vf "select='eq(n,$2)'" -fps_mode passthrough \
        -frames:v 1 "$TMP/$3.png" 2>/dev/null; }

for i in $(seq 0 $((NC-1))); do
  last=$(( NF[i]-1 ))
  for k in $(seq 0 $MAXDROP); do
    ext "${CLIPS[$i]}" $((k))        "h${i}_${k}"   # cabeza + k
    ext "${CLIPS[$i]}" $((last-k))   "t${i}_${k}"   # cola  - k
  done
done

# Energia de movimiento entre dos frames: diferencia absoluta media a 320x180.
# Misma metrica que usa el analisis de cadencia, asi que los valores son comparables.
energy() {
  ( cd "$TMP" && ffprobe -v error -f lavfi \
      -i "movie=$1.png[a];movie=$2.png[b];[a]scale=320:180[x];[b]scale=320:180[y];[x][y]blend=all_mode=difference,signalstats" \
      -show_entries frame_tags=lavfi.signalstats.YAVG -of csv=p=0 2>/dev/null | head -1 )
}

# Paso normal de referencia: media de los pasos consecutivos en la cola ($2=t)
# o en la cabeza ($2=h) de un clip.
baseline() {
  local i=$1 side=$2 a s=0 n=0 k
  for k in 0 1 2; do
    if [[ "$side" == t ]]; then a=$(energy "t${i}_$((k+1))" "t${i}_${k}")
    else                        a=$(energy "h${i}_${k}" "h${i}_$((k+1))"); fi
    [[ -n "$a" ]] && { s=$(awk -v s="$s" -v a="$a" 'BEGIN{print s+a}'); n=$((n+1)); }
  done
  awk -v s="$s" -v n="$n" 'BEGIN{print (n?s/n:1)}'
}

echo
echo "  midiendo costuras..."
declare -a BT BH SB
for i in $(seq 0 $((NC-1))); do BT[$i]=$(baseline "$i" t); BH[$i]=$(baseline "$i" h); done

# Referencia de cada costura: media del paso normal a AMBOS lados.
# Usar solo el lado saliente falsea el resultado cuando la costura va de una
# zona lenta a una rapida (justo lo que pasa en el punto de bucle).
mid() { awk -v a="$1" -v b="$2" 'BEGIN{print (a+b)/2}'; }
for j in $(seq 1 $((NC-1))); do SB[$j]=$(mid "${BT[$((j-1))]}" "${BH[$j]}"); done
(( LOOP )) && SB[$NPOS]=$(mid "${BT[$((NC-1))]}" "${BH[0]}")

# ── 3. Busqueda del reparto optimo de recortes ────────────────────────
# Coste de una costura = |energia/paso_normal - 1|. Penaliza igual el salto
# (ratio alto) que el congelado (ratio bajo).
cost() { awk -v e="$1" -v b="$2" 'BEGIN{ r=(b>0?e/b:1); d=r-1; print (d<0?-d:d) }'; }

BEST=""; BESTC=""
gen() {  # reparto recursivo de $DROP frames entre $NPOS posiciones
  local left=$1 pos=$2 acc="$3"
  if (( pos == NPOS )); then
    (( left != 0 )) && return
    local A; A="$(xargs <<<"$acc")"; local total=0 detail="" j=0
    for j in $(seq 1 $((NC-1))); do                    # costuras internas
      local hd; hd=$(cut -d' ' -f$j <<<"$A")
      local e; e=$(energy "t$((j-1))_0" "h${j}_${hd}")
      local c; c=$(cost "$e" "${SB[$j]}")
      total=$(awk -v t="$total" -v c="$c" 'BEGIN{print t+c}')
      detail="$detail $e"
    done
    if (( LOOP )); then                                # costura del bucle
      local td; td=$(cut -d' ' -f$NPOS <<<"$A")
      local e; e=$(energy "t$((NC-1))_${td}" "h0_0")
      local c; c=$(cost "$e" "${SB[$NPOS]}")
      total=$(awk -v t="$total" -v c="$c" 'BEGIN{print t+c}')
      detail="$detail $e"
    fi
    if [[ -z "$BESTC" ]] || awk -v a="$total" -v b="$BESTC" 'BEGIN{exit !(a<b)}'; then
      BESTC="$total"; BEST="$A"; BESTD="$(xargs <<<"$detail")"
    fi
    return
  fi
  local k
  for k in $(seq 0 $MAXDROP); do
    (( k > left )) && break
    gen $((left-k)) $((pos+1)) "$acc $k"
  done
}
gen "$DROP" 0 ""
BEST="$(xargs <<<"$BEST")"

# ── 3b. Estrategia alternativa: cortar SOBRE EL MOVIMIENTO ─────────────
# Recortar en las costuras no siempre sale barato: a veces la unica forma de
# cuadrar la duracion es estropear el punto de bucle, que es el sitio donde
# mas se nota porque se repite en cada vuelta y suele caer en un pasaje lento.
#
# La alternativa es dejar las costuras intactas y quitar los frames sobrantes
# DENTRO de un clip, en el tramo donde la camara va mas rapida. Ahi el desenfoque
# de movimiento tapa el salto: es el viejo principio de montaje de cortar sobre
# la accion. Un mismo error relativo se ve mucho menos cuanto mas rapido va la
# imagen, porque el ojo no puede seguir el detalle.
declare -a CUTLIST
if (( MOTION )) && (( DROP > 0 )); then
  echo "  buscando los tramos mas rapidos para cortar sobre el movimiento..."
  best_i=0; best_frames=""
  for i in $(seq 0 $((NC-1))); do
    ffprobe -v error -f lavfi \
      -i "movie=$(printf '%s' "${CLIPS[$i]}" | sed 's/:/\\:/g'),scale=320:180,tblend=all_mode=difference,signalstats" \
      -show_entries frame_tags=lavfi.signalstats.YAVG -of csv=p=0 2>/dev/null > "$TMP/m$i.csv" || true
    [[ -s "$TMP/m$i.csv" ]] || continue
    # top-$DROP transiciones mas rapidas, separadas entre si y lejos de los bordes
    sel=$(awk -v want="$DROP" 'NR>1{c++; v[c]=$1}
      END{ for(i=15;i<=c-15;i++) o[++n]=i
           for(i=1;i<n;i++) for(j=i+1;j<=n;j++) if(v[o[j]]>v[o[i]]){t=o[i];o[i]=o[j];o[j]=t}
           k=0
           for(i=1;i<=n && k<want;i++){ ok=1
             for(q=1;q<=k;q++){ d=o[i]-p[q]; if(d<0)d=-d; if(d<8) ok=0 }
             if(ok){ p[++k]=o[i]; printf "%s%d", (k>1?",":""), o[i] } } }' "$TMP/m$i.csv")
    if [[ -n "$sel" ]]; then best_i=$i; best_frames="$sel"; break; fi
  done
  if [[ -n "$best_frames" ]]; then
    for i in $(seq 0 $((NC-1))); do CUTLIST[$i]=""; HEAD[$i]=0; TAIL[$i]=0; done 2>/dev/null || true
    CUTLIST[$best_i]="$best_frames"
    MOTION_OK=1
  else
    echo "  (no hay tramo rapido claro; sigo con recorte en costuras)"
    MOTION=0
  fi
fi

# ── 4. Plan ───────────────────────────────────────────────────────────
declare -a HEAD TAIL
for i in $(seq 0 $((NC-1))); do HEAD[$i]=0; TAIL[$i]=0; done
if (( ${MOTION_OK:-0} == 0 )); then
  for j in $(seq 1 $((NC-1))); do HEAD[$j]=$(cut -d' ' -f$j <<<"$BEST"); done
  (( LOOP )) && TAIL[$((NC-1))]=$(cut -d' ' -f$NPOS <<<"$BEST")
else
  echo
  echo "  ESTRATEGIA: corte sobre el movimiento (costuras intactas)"
  for i in $(seq 0 $((NC-1))); do
    [[ -n "${CUTLIST[$i]:-}" ]] && printf "    clip %d  fuera los frames: %s\n" $((i+1)) "${CUTLIST[$i]}"
  done
fi

echo
echo "  PLAN DE MONTAJE"
KEEP=0
for i in $(seq 0 $((NC-1))); do
  a=${HEAD[$i]}; b=$(( NF[i]-1-TAIL[i] )); k=$((b-a+1))
  cl="${CUTLIST[$i]:-}"; [[ -n "$cl" ]] && k=$(( k - $(tr -cd ',' <<<"$cl" | wc -c) - 1 ))
  KEEP=$((KEEP+k))
  printf "    clip %d  frames %3d…%-3d = %3d   (fuera: %d cabeza, %d cola)\n" \
         $((i+1)) "$a" "$b" "$k" "${HEAD[$i]}" "${TAIL[$i]}"
done
printf "    %s\n" "----------------------------------------------------"
printf "    total %d frames = %s s a %s fps\n" "$KEEP" \
       "$(awk -v k="$KEEP" -v f="$FPS" 'BEGIN{printf "%.6f", k/f}')" "$FPS"

echo
echo "  COSTURAS RESULTANTES"
echo "    ratio 1,00 = la costura se mueve como un frame normal."
echo "    por encima de 1,60 se empieza a notar; por debajo de 0,50 parece congelado."
if (( ${MOTION_OK:-0} )); then
  # en modo movimiento las costuras quedan intactas: hay que medirlas de nuevo
  RD=""
  for j in $(seq 1 $((NC-1))); do RD="$RD $(energy "t$((j-1))_0" "h${j}_0")"; done
  (( LOOP )) && RD="$RD $(energy "t$((NC-1))_0" "h0_0")"
  BESTD="$(xargs <<<"$RD")"
fi
read -r -a EV <<<"$BESTD"
veredicto() { awk -v r="$1" 'BEGIN{
  if (r>=0.75 && r<=1.35)      print "excelente"
  else if (r>=0.50 && r<=1.60) print "correcta"
  else                         print "REVISAR" }'; }
for j in $(seq 1 $((NC-1))); do
  e="${EV[$((j-1))]}"; b="${SB[$j]}"
  r=$(awk -v e="$e" -v b="$b" 'BEGIN{printf "%.2f", (b>0?e/b:0)}')
  printf "    empalme %d→%d   ratio %-6s %s\n" "$j" "$((j+1))" "$r" "$(veredicto "$r")"
done
if (( LOOP )); then
  e="${EV[$((NPOS-1))]}"; b="${SB[$NPOS]}"
  r=$(awk -v e="$e" -v b="$b" 'BEGIN{printf "%.2f", (b>0?e/b:0)}')
  printf "    BUCLE  %d→1    ratio %-6s %s\n" "$NC" "$r" "$(veredicto "$r")"
fi

(( DRY )) && { echo; echo "  (--dry-run: no se codifica nada)"; echo; exit 0; }

# ── 5. Montaje y codificacion ─────────────────────────────────────────
# Normaliza a la resolucion pedida conservando el encuadre: recorta lo justo
# para que la relacion de aspecto cuadre y escala. Kling entrega 1916x1080,
# que no es 16:9 exacto; sin esto el reproductor lo estira por su cuenta.
# Redondeo al PAR MAS CERCANO, no hacia abajo: con 1916x1080 -> 1080p el alto
# ideal es 1077,75, y bajar a 1076 tira 2 px de mas (error de aspecto 0,16%
# en vez de 0,02%).
CH=$(awk -v w="${SW[0]}" -v h="${SH[0]}" -v ow="$OW" -v oh="$OH" \
     'BEGIN{ c=int(w*oh/ow + 0.5); if(c%2)c++; if(c>h){c=h; if(c%2)c--} print c }')
CY=$(awk -v h="${SH[0]}" -v c="$CH" 'BEGIN{print int((h-c)/2)}')

FC=""; LB=""
for i in $(seq 0 $((NC-1))); do
  cl="${CUTLIST[$i]:-}"
  if [[ -n "$cl" ]]; then
    # corte sobre el movimiento: se descartan frames sueltos del interior
    expr=""; IFS=',' read -ra FR <<<"$cl"
    for f in "${FR[@]}"; do expr="${expr}${expr:++}eq(n\\,${f})"; done
    FC="${FC}[${i}:v]select='not(${expr})',setpts=N/(${FPS}*TB)[s${i}];"
  else
    a=${HEAD[$i]}; b=$(( NF[i]-TAIL[i] ))
    FC="${FC}[${i}:v]trim=start_frame=${a}:end_frame=${b},setpts=N/(${FPS}*TB)[s${i}];"
  fi
  LB="${LB}[s${i}]"
done
FC="${FC}${LB}concat=n=${NC}:v=1:a=0,crop=${SW[0]}:${CH}:0:${CY},scale=${OW}:${OH}:flags=lanczos,setsar=1,format=yuv420p[v]"

IN=(); for c in "${CLIPS[@]}"; do IN+=(-i "$c"); done

echo
echo "  codificando..."
ffmpeg -y -v error -stats "${IN[@]}" -filter_complex "$FC" -map "[v]" \
  -fps_mode cfr -r "$FPS" \
  -c:v libx264 -preset slow -crf "$CRF" -profile:v high -level 4.2 \
  -x264-params "aq-mode=3:keyint=${FPS}:min-keyint=${FPS}:scenecut=0:ref=4:bframes=3" \
  -pix_fmt yuv420p -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
  -movflags +faststart -an "$OUT" 2>&1 | tail -1

# ── 6. Verificacion ───────────────────────────────────────────────────
RF=$(ffprobe -v error -select_streams v -count_frames -show_entries stream=nb_read_frames -of csv=p=0 "$OUT")
RD=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")
RS=$(ffprobe -v error -select_streams v -show_entries stream=width,height -of csv=p=0 "$OUT")

echo
echo "=================================================================="
echo "  RESULTADO: $OUT"
printf "    %s frames | %s s | %s\n" "$RF" "$RD" "$RS"
if [[ "$RF" == "$TARGET" ]]; then
  echo "    ✓ duracion exacta"
else
  echo "    ✗ ATENCION: esperaba $TARGET frames y hay $RF"
fi
echo
