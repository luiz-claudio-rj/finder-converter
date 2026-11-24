#!/bin/zsh
# Converter… — Ação Rápida do Finder (botão direito → Ações Rápidas → Converter…)
# Recebe os arquivos selecionados como argumentos, pergunta formato, tamanho e qualidade
# e salva o resultado ao lado do original. Usa ffmpeg (vídeo/áudio), avconvert (HDR→SDR),
# sips e cwebp (imagem). Mostra uma janela com os passos, o progresso e botão Cancelar.
#
# Para testar sem a janela de opções:
#   FORMATO="MP4 (H.264)" TAMANHO="720p (HD)" QUALIDADE="Baixa (arquivo menor)" ./converter.sh arquivo.mov
# SEM_JANELA=1 desliga a janela de progresso; SEM_AVISO=1 desliga a notificação.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
zmodload zsh/mathfunc   # int() nas contas do limite de tamanho
LOG="$HOME/Library/Logs/Converter.log"
PREFS="$HOME/Library/Application Support/Converter"

(( $# == 0 )) && exit 0

categoria() {
  case "${1:e:l}" in
    mp4|mov|m4v|mkv|avi|webm|wmv|flv|mpg|mpeg|3gp|mts|m2ts|ts|gif) echo video ;;
    mp3|m4a|aac|wav|aif|aiff|flac|ogg|opus|wma|caf) echo audio ;;
    jpg|jpeg|png|heic|heif|webp|tif|tiff|bmp|avif) echo imagem ;;
    *) echo outro ;;
  esac
}

# A categoria do primeiro arquivo reconhecido define as opções.
cat_alvo=""; primeiro=""
for f in "$@"; do
  c=$(categoria "$f")
  [[ $c != outro ]] && { cat_alvo=$c; primeiro=$f; break; }
done

if [[ -z $cat_alvo ]]; then
  osascript -e 'display alert "Converter" message "Nenhum arquivo de vídeo, áudio ou imagem foi selecionado."' >/dev/null
  exit 0
fi

limites=(); velocidades=()
case $cat_alvo in
  video)
    formatos=("MP4 (H.264)" "MP4 comprimido (HEVC)" "MOV" "WebM" "GIF" "MP3 (só o áudio)" "M4A (só o áudio)")
    tamanhos=("Original" "4K (2160p)" "1080p (Full HD)" "720p (HD)" "480p")
    rotulo_tamanho="Resolução:"
    nota_tamanho="Só diminui: vídeos menores que a opção ficam como estão."
    limites=("Sem limite" "8 MB (Discord)" "16 MB (WhatsApp)" "25 MB (e-mail)" "50 MB" "100 MB" "Outro valor…")
    velocidades=("Normal" "Rápida (chip do Mac)") ;;
  audio)
    formatos=("MP3" "M4A" "WAV" "FLAC" "OGG")
    tamanhos=()
    rotulo_tamanho=""; nota_tamanho="" ;;
  imagem)
    formatos=("JPG" "PNG" "WebP" "HEIC" "AVIF" "PDF")
    tamanhos=("Original" "4096 px" "2048 px" "1920 px" "1280 px" "1024 px" "512 px")
    rotulo_tamanho="Tamanho:"
    nota_tamanho="Medida do lado maior. Imagens menores que a opção ficam como estão." ;;
esac
qualidades=("Alta" "Média" "Baixa (arquivo menor)")
sem_qualidade=("WAV" "FLAC" "PNG" "PDF")              # formatos sem perda: a qualidade não se aplica
com_limite=("MP4 (H.264)" "MP4 comprimido (HEVC)" "MOV" "WebM")   # aceitam limite de tamanho do arquivo
com_velocidade=("MP4 (H.264)" "MP4 comprimido (HEVC)" "MOV")      # têm codificador no chip do Mac

# ───────────────────────── janela de opções ─────────────────────────
escolher_opcoes() {
  local res padrao n=$#
  res=$(mktemp -t converter-escolha)
  padrao="${formatos[1]}|Original|Média|Sem limite|Normal"
  [[ -s "$PREFS/ultima-$cat_alvo" ]] && padrao=$(<"$PREFS/ultima-$cat_alvo")
  local resumo="${primeiro:t}"; (( n > 1 )) && resumo+=" e mais $(( n - 1 ))"

  CONV_RESULT="$res" CONV_PADRAO="$padrao" CONV_RESUMO="$resumo" CONV_QTD="$n" \
  CONV_FORMATOS="${(pj:\n:)formatos}" CONV_TAMANHOS="${(pj:\n:)tamanhos}" \
  CONV_QUALIDADES="${(pj:\n:)qualidades}" CONV_SEM_QUALIDADE="${(pj:\n:)sem_qualidade}" \
  CONV_LIMITES="${(pj:\n:)limites}" CONV_COM_LIMITE="${(pj:\n:)com_limite}" \
  CONV_VELOCIDADES="${(pj:\n:)velocidades}" CONV_COM_VELOCIDADE="${(pj:\n:)com_velocidade}" \
  CONV_NOTA="$nota_tamanho" CONV_ROTULO_TAM="$rotulo_tamanho" \
  osascript -l JavaScript >/dev/null 2>&1 <<'JS'
ObjC.import('Cocoa');
const env = $.NSProcessInfo.processInfo.environment;
const get = k => { const v = env.objectForKey(k); return v.isNil() ? '' : ObjC.unwrap(v); };
const lista = k => get(k).split('\n').filter(x => x);
const RES = get('CONV_RESULT');
const formatos = lista('CONV_FORMATOS'), tamanhos = lista('CONV_TAMANHOS');
const qualidades = lista('CONV_QUALIDADES'), semQualidade = lista('CONV_SEM_QUALIDADE');
const limites = lista('CONV_LIMITES'), comLimite = lista('CONV_COM_LIMITE');
const velocidades = lista('CONV_VELOCIDADES'), comVelocidade = lista('CONV_COM_VELOCIDADE');
const padrao = get('CONV_PADRAO').split('|');
const qtd = parseInt(get('CONV_QTD')) || 1;
const OUTRO = 'Outro valor…';
const dicas = {
  'Alta': 'Alta: melhor imagem e som, arquivo maior.',
  'Média': 'Média: bom equilíbrio entre qualidade e tamanho.',
  'Baixa (arquivo menor)': 'Baixa: arquivo bem menor, com perda visível de qualidade.',
};

const app = $.NSApplication.sharedApplication;
app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);

const W = 460, temTam = tamanhos.length > 0, temLim = limites.length > 0, temVel = velocidades.length > 0;
const H = 250 + (temTam ? 46 : 0) + (temLim ? 34 : 0) + (temVel ? 34 : 0);
const win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer($.NSMakeRect(0, 0, W, H), 1, 2, false);
win.title = 'Converter';
win.level = 3;
const v = win.contentView;

function texto(txt, x, y, w, h, size, opts) {
  opts = opts || {};
  const t = $.NSTextField.labelWithString(txt);
  t.frame = $.NSMakeRect(x, y, w, h);
  t.font = opts.bold ? $.NSFont.boldSystemFontOfSize(size) : $.NSFont.systemFontOfSize(size);
  if (opts.direita) t.alignment = 1;
  if (opts.cinza) t.textColor = $.NSColor.secondaryLabelColor;
  if (opts.quebra) { t.cell.wraps = true; t.lineBreakMode = 0; } else t.lineBreakMode = 5;
  v.addSubview(t);
  return t;
}

ObjC.registerSubclass({
  name: 'OpcoesCtl',
  methods: {
    'mudou:': { types: ['void', ['id']], implementation: function (s) { atualizar(); } },
    'converter:': { types: ['void', ['id']], implementation: function (s) {
      let limite = temLim ? sel(pLimite) : 'Sem limite';
      if (limite === OUTRO) {
        const mb = parseFloat(String(ObjC.unwrap(campoMB.stringValue)).replace(',', '.'));
        if (!(mb > 0)) {
          dica.textColor = $.NSColor.systemRedColor;
          dica.stringValue = 'Digite o limite em MB, por exemplo 12.';
          win.makeFirstResponder(campoMB);
          return;
        }
        limite = mb + ' MB';
      }
      const r = [sel(pFormato), temTam ? sel(pTamanho) : 'Original', sel(pQualidade),
                 limite, temVel ? sel(pVelocidade) : 'Normal'].join('|');
      $(r).writeToFileAtomicallyEncodingError(RES, true, 4, null);
      app.terminate(null);
    } },
    'cancelar:': { types: ['void', ['id']], implementation: function (s) { app.terminate(null); } },
  },
});
const ctl = $.OpcoesCtl.alloc.init;
const sel = p => ObjC.unwrap(p.titleOfSelectedItem);

let y = H - 42;
texto(qtd > 1 ? 'Converter ' + qtd + ' arquivos' : 'Converter arquivo', 20, y, W - 40, 20, 14, { bold: true });
y -= 20;
texto(get('CONV_RESUMO'), 20, y, W - 40, 18, 12, { cinza: true });
y -= 44;

function linha(rotulo, itens, padraoItem, largura) {
  texto(rotulo, 20, y + 3, 90, 18, 13, { direita: true });
  const p = $.NSPopUpButton.alloc.initWithFramePullsDown($.NSMakeRect(118, y - 2, largura || W - 138, 26), false);
  itens.forEach(i => p.addItemWithTitle(i));
  if (itens.includes(padraoItem)) p.selectItemWithTitle(padraoItem);
  p.target = ctl; p.action = 'mudou:';
  v.addSubview(p);
  y -= 34;
  return p;
}
const pFormato = linha('Formato:', formatos, padrao[0]);
let pTamanho = null, pLimite = null, campoMB = null, rotuloMB = null, pVelocidade = null;
if (temTam) {
  pTamanho = linha(get('CONV_ROTULO_TAM'), tamanhos, padrao[1]);
  texto(get('CONV_NOTA'), 118, y + 12, W - 138, 16, 11, { cinza: true });   // logo abaixo do menu
  y -= 12;
}
if (temLim) {
  // "Outro valor…" mostra um campo para digitar o limite em MB ao lado do menu
  const salvoOutro = padrao[3] && !limites.includes(padrao[3]) && /^[\d.]+ MB$/.test(padrao[3]);
  campoMB = $.NSTextField.alloc.initWithFrame($.NSMakeRect(W - 112, y - 1, 60, 24));
  campoMB.placeholderString = 'ex.: 12';
  if (salvoOutro) campoMB.stringValue = padrao[3].split(' ')[0];
  v.addSubview(campoMB);
  rotuloMB = texto('MB', W - 46, y + 3, 30, 18, 13);
  pLimite = linha('Limite:', limites, salvoOutro ? OUTRO : padrao[3], W - 138 - 100);
}
const pQualidade = linha('Qualidade:', qualidades, padrao[2]);
if (temVel) pVelocidade = linha('Velocidade:', velocidades, padrao[4]);
const dica = texto('', 118, y - 14, W - 138, 32, 11, { cinza: true, quebra: true });

function atualizar() {
  const f = sel(pFormato);
  const semQ = semQualidade.includes(f);
  const podeLimitar = comLimite.includes(f);
  const limitando = podeLimitar && pLimite && sel(pLimite) !== 'Sem limite';
  const podeAcelerar = comVelocidade.includes(f) && !limitando;
  if (pTamanho) pTamanho.enabled = !f.includes('só o áudio');
  if (pLimite) {
    pLimite.enabled = podeLimitar;
    const outro = podeLimitar && sel(pLimite) === OUTRO;
    campoMB.hidden = !outro; rotuloMB.hidden = !outro;
  }
  pQualidade.enabled = !semQ && !limitando;
  if (pVelocidade) pVelocidade.enabled = podeAcelerar;
  dica.textColor = $.NSColor.secondaryLabelColor;
  if (limitando)
    dica.stringValue = 'Limite: o vídeo é comprimido em duas passadas para caber no tamanho. Qualidade e velocidade ficam automáticas.';
  else if (semQ)
    dica.stringValue = f + ' não tem perda: a qualidade é sempre a máxima.';
  else if (podeAcelerar && sel(pVelocidade).startsWith('Rápida'))
    dica.stringValue = 'Rápida: usa o chip de vídeo do Mac, várias vezes mais rápido. O arquivo sai um pouco maior.';
  else
    dica.stringValue = dicas[sel(pQualidade)] || '';
}
atualizar();

function botao(nome, acao, x, w, tecla) {
  const b = $.NSButton.buttonWithTitleTargetAction(nome, ctl, acao);
  b.frame = $.NSMakeRect(x, 14, w, 30);
  b.keyEquivalent = tecla;
  v.addSubview(b);
}
botao('Cancelar', 'cancelar:', W - 230, 100, '\u001b');
botao('Converter', 'converter:', W - 120, 100, '\r');

win.center;
win.makeKeyAndOrderFront(null);
app.activateIgnoringOtherApps(true);
app.run;
JS
  ESCOLHA=$(<"$res"); rm -f "$res"
}

if [[ -z $FORMATO ]]; then
  escolher_opcoes "$@"
  [[ -z $ESCOLHA ]] && exit 0
  IFS='|' read -r FORMATO TAMANHO QUALIDADE LIMITE VELOCIDADE <<< "$ESCOLHA"
  mkdir -p "$PREFS" && print -r -- "$ESCOLHA" > "$PREFS/ultima-$cat_alvo"
fi
TAMANHO=${TAMANHO:-Original}; QUALIDADE=${QUALIDADE:-Média}
LIMITE=${LIMITE:-Sem limite}; VELOCIDADE=${VELOCIDADE:-Normal}
[[ -z $FORMATO ]] && exit 0

case $FORMATO in
  "MP4 (H.264)")           ext=mp4  ;;
  "MP4 comprimido (HEVC)") ext=mp4  ;;
  MOV)                     ext=mov  ;;
  WebM)                    ext=webm ;;
  GIF)                     ext=gif  ;;
  "MP3 (só o áudio)"|MP3)  ext=mp3  ;;
  "M4A (só o áudio)"|M4A)  ext=m4a  ;;
  WAV)  ext=wav  ;;  FLAC) ext=flac ;;  OGG) ext=ogg ;;
  JPG)  ext=jpg  ;;  PNG)  ext=png  ;;  WebP) ext=webp ;;
  HEIC) ext=heic ;;  AVIF) ext=avif ;;  PDF)  ext=pdf  ;;
  *) exit 1 ;;
esac

# Tamanho: ALVO = lado menor do vídeo (1080p → 1080) ou lado maior da imagem; 0 = original.
case $TAMANHO in
  4K*)     ALVO=2160; TAM_CURTO="4K" ;;
  1080p*)  ALVO=1080; TAM_CURTO="1080p" ;;
  720p*)   ALVO=720;  TAM_CURTO="720p" ;;
  480p*)   ALVO=480;  TAM_CURTO="480p" ;;
  <->" px") ALVO=${TAMANHO%% *}; TAM_CURTO=$TAMANHO ;;
  *)       ALVO=0;    TAM_CURTO="" ;;
esac
[[ $FORMATO == *"só o áudio"* ]] && { ALVO=0; TAM_CURTO=""; }

# Qualidade: Q = 1 (alta), 2 (média, o padrão de antes) ou 3 (baixa).
case $QUALIDADE in
  Alta)   Q=1; QUAL_CURTA="qualidade alta" ;;
  Baixa*) Q=3; QUAL_CURTA="qualidade baixa" ;;
  *)      Q=2; QUAL_CURTA="qualidade média" ;;
esac
(( ${sem_qualidade[(Ie)$FORMATO]} )) && QUAL_CURTA=""

# Limite do arquivo em MB ("16 MB (WhatsApp)", "12.5 MB"…); 0 = sem limite.
LIM_MB=${${LIMITE%% *}/,/.}
[[ $LIM_MB == <->(.<->|) ]] && (( LIM_MB > 0 )) && (( ${com_limite[(Ie)$FORMATO]} )) || LIM_MB=0
LIMITADO=$(( LIM_MB > 0 ))
LIM_TXT=${LIM_MB/./,}   # "5,5" para mostrar na janela
(( LIMITADO )) && QUAL_CURTA=""

# Velocidade "Rápida": codificador de vídeo do chip (VideoToolbox), só em H.264/HEVC e sem limite.
RAPIDA=0
[[ $VELOCIDADE == Rápida* ]] && (( ${com_velocidade[(Ie)$FORMATO]} && ! LIMITADO )) && RAPIDA=1

#                 alta  média baixa
crf_x264=(        18    23    28 )
crf_x265=(        24    28    32 )
crf_vp9=(         28    32    38 )
vt_h264=(         75    66    55 )   # chip do Mac (-q:v), calibrado para dar tamanhos parecidos com o x264
vt_hevc=(         58    50    42 )
aac_video=(       192k  160k  96k )
opus_video=(      160k  128k  96k )
gif_fps=(         15    12    8 )
gif_cores=(       256   256   128 )
mp3_q=(           0     2     5 )
m4a_br=(          256k  192k  128k )
ogg_br=(          160k  128k  96k )
jpg_q=(           95    85    70 )
webp_q=(          92    85    70 )
heic_q=(          90    80    60 )
avif_q=(          90    80    60 )

# ───────────────────────── janela de progresso ─────────────────────────
# O script escreve uma linha em $ST e a janela (JXA/Cocoa) lê a cada 0,3 s:
#   P|<porcentagem ou -1>|<título>|<passo>|<arquivo i de N>   progresso (-1 = barra animada)
#   FIM|<título>|<detalhe>                     terminou; caminhos gerados em $ST.saidas
#   SAIR                                       fecha a janela
# O botão Cancelar cria $ST.cancel.
ST=$(mktemp -t converter-status); CANCEL="$ST.cancel"; SAIDAS="$ST.saidas"
: > "$SAIDAS"
terminou=0
trap '(( terminou )) || print -r -- SAIR > "$ST"' EXIT

estado() {
  [[ -n $DEBUG_ESTADOS ]] && print -r -- "$1" >> "$DEBUG_ESTADOS"   # para testes
  print -r -- "$1" > "$ST.tmp" && mv -f "$ST.tmp" "$ST"
}
cancelado() { [[ -e $CANCEL ]]; }

abre_janela() {
  CONV_STATUS="$ST" osascript -l JavaScript >/dev/null 2>&1 <<'JS' &!
ObjC.import('Cocoa');
const env = $.NSProcessInfo.processInfo.environment;
const ST = ObjC.unwrap(env.objectForKey('CONV_STATUS'));
const CANCEL = ST + '.cancel', SAIDAS = ST + '.saidas';
const app = $.NSApplication.sharedApplication;
app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);

const W = 500, H = 150;
const win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer($.NSMakeRect(0, 0, W, H), 1, 2, false);
win.title = 'Converter';
win.level = 3;                 // flutuante, fica por cima das outras janelas
win.releasedWhenClosed = false;
const v = win.contentView;

function texto(y, h, size, bold) {
  const t = $.NSTextField.labelWithString('');
  t.frame = $.NSMakeRect(20, y, W - 40, h);
  t.font = bold ? $.NSFont.boldSystemFontOfSize(size) : $.NSFont.systemFontOfSize(size);
  t.lineBreakMode = 5;         // corta no meio: "IMG_22…(1).mp4"
  v.addSubview(t);
  return t;
}
const titulo = texto(H - 38, 20, 13, true);           // "IMG_2261.MOV → IMG_2261.mp4"
const passo = texto(H - 62, 18, 12, false);           // "Passo 1 de 2: ajustando cores (HDR → SDR)"
const barra = $.NSProgressIndicator.alloc.initWithFrame($.NSMakeRect(20, H - 90, W - 40, 20));
barra.indeterminate = false; barra.minValue = 0; barra.maxValue = 100;
v.addSubview(barra);
const detalhe = texto(18, 18, 11, false);             // "45% · faltam ~1 min · arquivo 2 de 5"
detalhe.frame = $.NSMakeRect(20, 18, W - 160, 18);
detalhe.textColor = $.NSColor.secondaryLabelColor;
titulo.stringValue = 'Preparando…';

let fim = false, cancelando = false, atual = '', inicio = Date.now();

function ler(p) {
  const s = $.NSString.stringWithContentsOfFileEncodingError(p, 4, null);
  return s.isNil() ? null : ObjC.unwrap(s);
}
function tempo(s) {
  s = Math.max(1, Math.round(s));
  return s < 60 ? s + ' s' : Math.floor(s / 60) + ' min ' + String(s % 60).padStart(2, '0') + ' s';
}
function sair() { app.terminate(null); }

ObjC.registerSubclass({
  name: 'ConverterCtl',
  methods: {
    'cancelar:': { types: ['void', ['id']], implementation: function (b) {
      $('1').writeToFileAtomicallyEncodingError(CANCEL, true, 4, null);
      cancelando = true; b.enabled = false; passo.stringValue = 'Cancelando…';
    } },
    'mostrar:': { types: ['void', ['id']], implementation: function (b) {
      const lista = (ler(SAIDAS) || '').split('\n').filter(x => x);
      const urls = $.NSMutableArray.array;
      lista.forEach(p => urls.addObject($.NSURL.fileURLWithPath(p)));
      if (lista.length) $.NSWorkspace.sharedWorkspace.activateFileViewerSelectingURLs(urls);
      sair();
    } },
    'fechar:': { types: ['void', ['id']], implementation: function (b) { sair(); } },
    'tick:': { types: ['void', ['id']], implementation: function (t) { tick(t); } },
  },
});
const ctl = $.ConverterCtl.alloc.init;

function botao(nome, acao, x, w) {
  const b = $.NSButton.buttonWithTitleTargetAction(nome, ctl, acao);
  b.frame = $.NSMakeRect(x, 12, w, 30);
  v.addSubview(b);
  return b;
}
const bCancelar = botao('Cancelar', 'cancelar:', W - 120, 100);

function tick(timer) {
  if (fim) return;
  const linha = ler(ST);
  if (linha === null) { sair(); return; }
  const c = linha.trim().split('|');
  if (c[0] === 'SAIR') { sair(); return; }
  if (c[0] === 'FIM') {
    fim = true; timer.invalidate;
    barra.indeterminate = false; barra.doubleValue = 100;
    titulo.stringValue = c[1] || 'Pronto';
    passo.stringValue = c[2] || '';
    detalhe.stringValue = '';
    barra.hidden = true;
    bCancelar.removeFromSuperview;
    const temSaida = (ler(SAIDAS) || '').trim().length > 0;
    const bOk = botao('OK', 'fechar:', W - 120, 100);
    bOk.keyEquivalent = temSaida ? '' : '\r';
    if (temSaida) {
      const bMostrar = botao('Mostrar no Finder', 'mostrar:', W - 280, 156);
      bMostrar.keyEquivalent = '\r';
    }
    const som = $.NSSound.soundNamed('Glass'); if (!som.isNil()) som.play;
    $.NSFileManager.defaultManager.removeItemAtPathError(ST, null);
    app.activateIgnoringOtherApps(true);
    return;
  }
  if (c[0] !== 'P' || cancelando) return;
  const pct = parseFloat(c[1]);
  const chave = c[2] + '|' + c[3];                    // o tempo restante recomeça a cada passo
  if (chave !== atual) { atual = chave; inicio = Date.now(); }
  titulo.stringValue = c[2] || '';
  passo.stringValue = c[3] || '';
  const arquivo = c[4] || '';
  if (!(pct >= 0)) {
    if (!barra.indeterminate) { barra.indeterminate = true; barra.startAnimation(null); }
    detalhe.stringValue = arquivo;
  } else {
    if (barra.indeterminate) { barra.stopAnimation(null); barra.indeterminate = false; }
    barra.doubleValue = pct;
    let d = Math.floor(pct) + '%';
    const passou = (Date.now() - inicio) / 1000;
    if (pct >= 2 && pct < 100 && passou > 3) d += ' · faltam ~' + tempo(passou * (100 - pct) / pct);
    if (arquivo) d += ' · ' + arquivo;
    detalhe.stringValue = d;
  }
}

$.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(0.3, ctl, 'tick:', null, true);
win.center;
win.makeKeyAndOrderFront(null);
app.activateIgnoringOtherApps(true);
app.run;
JS
}

# ───────────────────────── conversão ─────────────────────────
# "foto.png" → "foto.jpg"; se já existir, "foto (1).jpg", "foto (2).jpg"…
destino() {
  local base="${1:r}" out="${1:r}.$ext" n=1
  while [[ -e $out ]]; do out="$base ($n).$ext"; (( n++ )); done
  echo "$out"
}

# Um arquivo com extensão de vídeo pode ser, na verdade, uma playlist (HLS, concat…) que
# faz o ffmpeg ler outros arquivos ou endereços. Por isso o ffprobe e o ffmpeg só abrem
# arquivos locais (-protocol_whitelist) e só com os leitores de formato desta lista
# (-format_whitelist). Qualquer outro formato é recusado pelas duas ferramentas.
#   mov = MOV/MP4/M4A/3GP · matroska = MKV/WebM · asf = WMV/WMA · mpeg/mpegts = MPG/TS/MTS
FORMATOS_OK="mov,matroska,avi,asf,flv,mpeg,mpegts,gif,mp3,wav,aiff,flac,ogg,caf,aac"
SEGURO=(-protocol_whitelist file -format_whitelist "$FORMATOS_OK")

probe() { ffprobe -v error $SEGURO "${@[1,-2]}" "file:${@[-1]}"; }

# Só segue se o ffprobe conseguiu ler o arquivo com um dos formatos permitidos.
entrada_segura() {
  local fmt; fmt=$(probe -show_entries format=format_name -of default=nw=1:nk=1 "$1" 2>/dev/null)
  [[ -n $fmt ]]
}

duracao_us() {
  local d; d=$(probe -show_entries format=duration -of default=nw=1:nk=1 "$1" 2>/dev/null)
  [[ $d == <->(.<->|) ]] && printf '%.0f' $(( d * 1000000 )) || echo 0
}

mb() { awk -v b="$1" 'BEGIN { if (b >= 1048576) printf "%.1f MB", b/1048576; else printf "%d KB", (b+1023)/1024 }'; }

# Cada arquivo passa por 1 ou mais passos (ex.: vídeo HDR = ajustar cores + converter).
# passo <n> "<descrição>" [porcentagem]  → anuncia "Passo n de N: descrição" na janela
# progresso <porcentagem>                → atualiza só a barra do passo atual
passo() { PASSO="Passo $1 de $PASSOS: $2"; estado "P|${3:--1}|$TITULO|$PASSO|$ARQ"; }
progresso() { estado "P|$1|$TITULO|$PASSO|$ARQ"; }

# "convertendo para MP4 (H.264), 720p, qualidade baixa"
descricao_conversao() {
  local d
  case $FORMATO in
    *"só o áudio"*) d="extraindo o áudio em ${FORMATO%% *}" ;;
    GIF)            d="gerando o GIF" ;;
    *)              d="convertendo para $FORMATO" ;;
  esac
  [[ -n $TAM_CURTO && $1 != sem-tamanho ]] && d+=", $TAM_CURTO"
  [[ -n $QUAL_CURTA ]] && d+=", $QUAL_CURTA"
  (( RAPIDA )) && d+=", rápida"
  echo "$d"
}

# Lê o "-progress" do ffmpeg e atualiza a janela.
acompanha_ffmpeg() {
  local k v pct
  while IFS='=' read -r k v; do
    if [[ $k == out_time_us && $v == <-> ]] && (( DUR > 0 )); then
      pct=$(( v * 100 / DUR )); (( pct > 99 )) && pct=99
      progresso $pct
    fi
  done
}

# Roda o ffmpeg em segundo plano para poder encerrá-lo na hora se o usuário cancelar.
ff() {
  ffmpeg -nostdin -hide_banner -loglevel error -nostats -progress pipe:1 -y $SEGURO -i "file:$in" "$@" > >(acompanha_ffmpeg) &
  local pid=$!
  while kill -0 $pid 2>/dev/null; do
    cancelado && { kill -9 $pid 2>/dev/null; break; }   # o arquivo parcial é apagado depois
    sleep 0.3
  done
  wait $pid; local rc=$?
  cancelado && return 1
  return $rc
}

# Filtro de redução do vídeo: o lado menor fica com ALVO pixels. Vídeo que já é menor
# não passa pelo filtro (nada de aumentar nem de mexer 1 px).
escala_video() {
  (( ALVO )) || return
  local dims w h
  dims=( $(probe -select_streams v:0 -show_entries stream=width,height -of default=nw=1:nk=1 "$1" 2>/dev/null) )
  w=$dims[1]; h=$dims[2]
  [[ $w == <-> && $h == <-> ]] || return
  (( (w < h ? w : h) > ALVO )) || return
  print -r -- "scale='if(gt(iw,ih),-2,$ALVO)':'if(gt(iw,ih),$ALVO,-2)',"
}
PAR="scale=trunc(iw/2)*2:trunc(ih/2)*2"   # H.264/HEVC exigem largura e altura pares

# Lado maior da imagem, em pixels
lado_maior() {
  sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null | awk '/pixel(Width|Height)/ { if ($2 > m) m = $2 } END { print m + 0 }'
}
# A imagem precisa ser reduzida? (só se for maior que o tamanho escolhido)
reduz_imagem() { (( ALVO > 0 )) && (( $(lado_maior "$1") > ALVO )); }

# Tenta o codificador do chip do Mac; se ele não estiver disponível (alguns Macs Intel),
# anota no registro e avisa na janela que vai seguir com a conversão normal.
chip_ou_normal() {
  local codec=$1; shift
  ff -map 0:v:0 -map '0:a:0?' -vf "$esc$PAR" "$@" -c:a aac -b:a $aac_video[Q] -movflags +faststart "$out" && return 0
  cancelado && return 1
  print -r -- "$(date '+%F %T') $codec indisponível, usando conversão normal: $in" >> "$LOG"
  passo $PASSOS "$(descricao_conversao) (chip indisponível, usando a normal)" 0
  return 1
}

converter() {
  local in="$1" out="$2" esc=""
  (( LIMITADO )) && { converter_limitado "$in" "$out"; return; }
  [[ $cat_alvo == video ]] && esc=$(escala_video "$in")
  local reduz=(); [[ $cat_alvo == imagem ]] && reduz_imagem "$in" && reduz=(-Z $ALVO)
  case $FORMATO in
    "MP4 (H.264)"|MOV)
      (( RAPIDA )) && chip_ou_normal h264_videotoolbox -c:v h264_videotoolbox -q:v $vt_h264[Q] -pix_fmt yuv420p && return 0
      cancelado && return 1
      ff -map 0:v:0 -map '0:a:0?' -vf "$esc$PAR" -c:v libx264 -crf $crf_x264[Q] -preset medium -pix_fmt yuv420p \
        -c:a aac -b:a $aac_video[Q] -movflags +faststart "$out" ;;
    "MP4 comprimido (HEVC)")
      (( RAPIDA )) && chip_ou_normal hevc_videotoolbox -c:v hevc_videotoolbox -q:v $vt_hevc[Q] -tag:v hvc1 -pix_fmt yuv420p && return 0
      cancelado && return 1
      ff -map 0:v:0 -map '0:a:0?' -vf "$esc$PAR" -c:v libx265 -crf $crf_x265[Q] -preset fast -pix_fmt yuv420p -tag:v hvc1 \
        -x265-params log-level=error -c:a aac -b:a $aac_video[Q] -movflags +faststart "$out" ;;
    WebM)
      ff -map 0:v:0 -map '0:a:0?' -vf "${esc%,}${esc:+,}null" -c:v libvpx-vp9 -crf $crf_vp9[Q] -b:v 0 -row-mt 1 \
        -deadline good -cpu-used 4 -c:a libopus -b:a $opus_video[Q] "$out" ;;
    GIF)
      # com tamanho "Original", o GIF fica com no máximo 720 px de largura (GIF grande pesa muito)
      (( ALVO == 0 )) && esc="scale='min(720,iw)':-1:flags=lanczos,"
      ff -vf "fps=$gif_fps[Q],${esc}split[a][b];[a]palettegen=max_colors=$gif_cores[Q][p];[b][p]paletteuse" \
        -loop 0 "$out" ;;
    MP3*) ff -map 0:a:0 -vn -c:a libmp3lame -q:a $mp3_q[Q] "$out" ;;
    M4A*) ff -map 0:a:0 -vn -c:a aac -b:a $m4a_br[Q] "$out" ;;
    WAV)  ff -map 0:a:0 -vn -c:a pcm_s16le "$out" ;;
    FLAC) ff -map 0:a:0 -vn -c:a flac "$out" ;;
    OGG)  ff -map 0:a:0 -vn -c:a libopus -b:a $ogg_br[Q] "$out" ;;
    JPG)  sips $reduz -s format jpeg -s formatOptions $jpg_q[Q] "$in" --out "$out" >/dev/null ;;
    PNG)  sips $reduz -s format png "$in" --out "$out" >/dev/null ;;
    HEIC) sips $reduz -s format heic -s formatOptions $heic_q[Q] "$in" --out "$out" >/dev/null ;;
    AVIF) sips $reduz -s format avif -s formatOptions $avif_q[Q] "$in" --out "$out" >/dev/null ;;
    PDF)  sips $reduz -s format pdf "$in" --out "$out" >/dev/null ;;
    WebP)
      if [[ ${in:e:l} == (jpg|jpeg|png|tif|tiff|webp) ]] && (( ! $#reduz )); then
        cwebp -quiet -q $webp_q[Q] -metadata icc "$in" -o "$out"
      else
        # HEIC/AVIF/BMP, ou imagem que precisa ser reduzida: passa por um PNG temporário (2 passos)
        local tmp; tmp=$(mktemp -t converter).png
        if (( $#reduz )); then passo 1 "reduzindo para $ALVO px" $PCT_IMG
        else passo 1 "lendo a imagem ${in:e:u}" $PCT_IMG; fi
        sips $reduz -s format png "$in" --out "$tmp" >/dev/null \
          && { passo 2 "$(descricao_conversao sem-tamanho)" $PCT_IMG; cwebp -quiet -q $webp_q[Q] "$tmp" -o "$out"; }
        local rc=$?; rm -f "$tmp"; return $rc
      fi ;;
  esac
}

# ───────────── limite de tamanho do arquivo (ex.: 16 MB para o WhatsApp) ─────────────
# Calcula a taxa de bits que cabe no limite e codifica em duas passadas: a 1ª só analisa
# o vídeo, a 2ª comprime usando essa análise, o que acerta o tamanho com precisão.
# Se a taxa ficar baixa para a resolução, reduz a resolução sozinho (e avisa no passo).
# Se mesmo assim passar do limite, refaz a 2ª passada com 10% a menos (até 2 vezes).
# Orçamento do limite: define ORC_V e ORC_A (kbit/s de vídeo e de áudio) para o arquivo $1.
# Falha (com MOTIVO) se o vídeo for longo demais para o limite. O laço principal chama
# antes de tudo, para não gastar tempo ajustando as cores de um vídeo que não vai caber.
orcamento_limite() {
  local dur_us; dur_us=$(duracao_us "$1")
  (( dur_us > 0 )) || { MOTIVO="Não foi possível ler a duração do vídeo."; return 1; }
  # total em kbit/s, com 4% de folga para o contêiner
  local total=$(( LIM_MB * 1048576 * 8 * 0.96 / 1000.0 / (dur_us / 1000000.0) ))
  local tem_audio
  tem_audio=$(probe -select_streams a:0 -show_entries stream=index -of csv=p=0 "$1" 2>/dev/null)
  ORC_A=0
  if [[ -n $tem_audio ]]; then
    if (( total > 1500 )); then ORC_A=128; elif (( total > 400 )); then ORC_A=96; else ORC_A=64; fi
  fi
  ORC_V=$(( int(total - ORC_A) ))
  if (( ORC_V < 80 )); then
    MOTIVO="O vídeo é longo demais para caber em $LIM_TXT MB com qualidade aceitável. Escolha um limite maior."
    print -r -- "$(date '+%F %T') limite impossível ($ORC_V kbit/s de vídeo): $ARQ_ORIGINAL → $LIM_TXT MB" >> "$LOG"
    return 1
  fi
}

converter_limitado() {
  local in="$1" out="$2"
  local B=$(( PASSOS - 2 ))                         # passos anteriores (ajuste de cores do HDR)
  local alvo_bytes=$(( int(LIM_MB * 1048576) ))
  orcamento_limite "$in" || return 1
  local v=$ORC_V a=$ORC_A

  # resolução automática: HEVC e VP9 rendem ~40% mais por bit que o H.264
  local fator=1.0; [[ $FORMATO == (*HEVC*|WebM) ]] && fator=0.6
  local auto=0
  if   (( v < 450 * fator ));  then auto=360
  elif (( v < 900 * fator ));  then auto=480
  elif (( v < 1800 * fator )); then auto=720
  elif (( v < 4000 * fator )); then auto=1080
  fi
  local ALVO=$ALVO nota=""
  if (( auto && (ALVO == 0 || auto < ALVO) )); then ALVO=$auto; fi
  local esc; esc=$(escala_video "$in")
  [[ -n $esc ]] && (( auto && ALVO == auto )) && nota=" (reduzido para ${auto}p)"

  local tmp; tmp=$(mktemp -d -t converter-2p)
  local vf="$esc$PAR" p1 p2 aud extra=(-movflags +faststart)
  venc() {   # codificador de vídeo para a taxa $1 (kbit/s)
    case $FORMATO in
      "MP4 (H.264)"|MOV)       print -r -- "-c:v libx264 -preset medium -pix_fmt yuv420p -b:v ${1}k" ;;
      "MP4 comprimido (HEVC)") print -r -- "-c:v libx265 -preset fast -pix_fmt yuv420p -tag:v hvc1 -b:v ${1}k" ;;
      WebM)                    print -r -- "-c:v libvpx-vp9 -row-mt 1 -deadline good -cpu-used 4 -b:v ${1}k" ;;
    esac
  }
  case $FORMATO in
    "MP4 comprimido (HEVC)")
      p1=(-x265-params "pass=1:stats=$tmp/x265.log:log-level=error")
      p2=(-x265-params "pass=2:stats=$tmp/x265.log:log-level=error")
      aud=(-c:a aac -b:a ${a}k) ;;
    WebM)
      vf="${esc%,}${esc:+,}null"; extra=()
      p1=(-pass 1 -passlogfile "$tmp/2p"); p2=(-pass 2 -passlogfile "$tmp/2p")
      aud=(-c:a libopus -b:a ${a}k) ;;
    *)
      p1=(-pass 1 -passlogfile "$tmp/2p"); p2=(-pass 2 -passlogfile "$tmp/2p")
      aud=(-c:a aac -b:a ${a}k) ;;
  esac

  local rc=0 tentativa=0
  passo $(( B + 1 )) "analisando o vídeo (1ª de 2 passadas)" 0
  ff -map 0:v:0 -vf "$vf" ${=$(venc $v)} $p1 -an -f null /dev/null || rc=1
  if (( ! rc )); then
    passo $(( B + 2 )) "comprimindo para caber em $LIM_TXT MB$nota (2ª passada)" 0
    ff -map 0:v:0 -map '0:a:0?' -vf "$vf" ${=$(venc $v)} $p2 $aud $extra "$out" || rc=1
  fi
  while (( ! rc && tentativa < 2 )) && [[ -s $out ]] && (( $(stat -f%z "$out") > alvo_bytes )); do
    (( tentativa++, PASSOS++ ))
    v=$(( int(v * 0.9) ))
    passo $PASSOS "ficou um pouco acima, ajustando para caber em $LIM_TXT MB" 0
    ff -map 0:v:0 -map '0:a:0?' -vf "$vf" ${=$(venc $v)} $p2 $aud $extra "$out" || rc=1
  done
  rm -rf "$tmp"
  (( rc )) && return 1
  if (( $(stat -f%z "$out") > alvo_bytes )); then
    MOTIVO="Não foi possível deixar o vídeo abaixo de $LIM_TXT MB. Tente um limite um pouco maior."
    return 1
  fi
  return 0
}

# Vídeo HDR (iPhone grava em HLG/Dolby Vision) convertido direto fica com cores lavadas.
# Nesse caso o avconvert da Apple gera antes uma cópia SDR, que o ffmpeg então converte.
eh_hdr() {
  local trc
  trc=$(probe -select_streams v:0 -show_entries stream=color_transfer -of default=nw=1:nk=1 "$1" 2>/dev/null)
  trc=${trc%%[,[:space:]]*}
  [[ $trc == arib-std-b67 || $trc == smpte2084 ]]
}

# avconvert --progress escreve "avconvert progress:  42.10% complete" separado por \r.
para_sdr() {
  local origem="$1" sdr="$2" linha
  avconvert -p PresetHighestQuality -s "$origem" -o "$sdr" --replace --progress 2>>"$LOG" \
    | tr -u '\r' '\n' | while read -r linha; do
        if cancelado; then pkill -f -- "-o $sdr" 2>/dev/null; break; fi
        [[ $linha =~ 'progress: *([0-9]+)' ]] && (( match[1] > 0 && match[1] < 100 )) \
          && progresso $match[1]
      done
  cancelado && return 1
  [[ -s $sdr ]]
}

[[ -n $SEM_JANELA ]] || abre_janela

total=$#; i=0; ok=0; falhas=0; pulados=0; ultimo=""; ultimo_orig=""
for f in "$@"; do
  (( i++ ))
  cancelado && break
  [[ -f $f ]] || { (( pulados++ )); continue; }
  # GIF é tratado como vídeo; "outro" e categorias diferentes da escolhida são pulados.
  if [[ $(categoria "$f") != $cat_alvo ]]; then (( pulados++ )); continue; fi
  if [[ $cat_alvo != imagem ]] && ! entrada_segura "$f"; then
    (( falhas++ )); print -r -- "$(date '+%F %T') recusado (não é um arquivo de mídia comum): $f" >> "$LOG"; continue
  fi
  out=$(destino "$f")
  TITULO="${f:t} → ${out:t}"
  ARQ=""; (( total > 1 )) && ARQ="arquivo $i de $total"
  estado "P|-1|$TITULO|Analisando o arquivo…|$ARQ"

  ARQ_ORIGINAL=$f
  # Com limite de tamanho, confere logo se o vídeo cabe (antes de qualquer passo demorado)
  if (( LIMITADO )) && ! orcamento_limite "$f"; then
    (( falhas++ )); continue
  fi

  # Quantos passos este arquivo vai ter
  hdr=0
  [[ $cat_alvo == video && $FORMATO != (MP3|M4A)* ]] && eh_hdr "$f" && hdr=1
  PASSOS=$(( 1 + hdr + LIMITADO ))   # HDR: +1 (ajustar cores); limite: +1 (duas passadas)
  if [[ $FORMATO == WebP ]]; then
    [[ ${f:e:l} != (jpg|jpeg|png|tif|tiff|webp) ]] && PASSOS=2
    reduz_imagem "$f" && PASSOS=2
  fi
  PCT_IMG=$(( (i - 1) * 100 / total ))   # imagens: a barra mostra o andamento do lote

  entrada="$f"; sdr=""
  if (( hdr )); then
    sdr="$(mktemp -d -t converter)/sdr.mov"
    passo 1 "ajustando as cores (HDR → SDR)"
    para_sdr "$f" "$sdr" && entrada="$sdr"
  fi
  if [[ $cat_alvo == imagem ]]; then
    (( PASSOS == 1 )) && passo 1 "$(descricao_conversao)" $PCT_IMG   # com 2 passos, converter() anuncia
  else
    DUR=$(duracao_us "$entrada")
    (( LIMITADO )) || passo $PASSOS "$(descricao_conversao)" $(( DUR > 0 ? 0 : -1 ))   # com limite, converter_limitado anuncia
  fi

  if ! cancelado && converter "$entrada" "$out" 2>>"$LOG" && [[ -s $out ]]; then
    (( ok++ )); ultimo="$out"; ultimo_orig="$f"; print -r -- "$out" >> "$SAIDAS"
  else
    rm -f "$out"
    cancelado || { (( falhas++ )); print -r -- "$(date '+%F %T') falhou: $f → $FORMATO" >> "$LOG"; }
  fi
  [[ -n $sdr ]] && rm -rf "${sdr:h}"
done

# ───────────────────────── resumo ─────────────────────────
if cancelado; then
  tit="Conversão cancelada"
  det="$ok concluído(s) antes de cancelar"
elif (( ok == 1 && falhas == 0 )); then
  tit="Pronto: ${ultimo:t}"
  det="Salvo em ${ultimo:h:t} · $(mb $(stat -f%z "$ultimo")) (original: $(mb $(stat -f%z "$ultimo_orig")))"
elif (( ok > 0 && falhas == 0 )); then
  tit="Pronto: $ok arquivos convertidos para $FORMATO"
  det="Salvos ao lado dos originais"
elif (( ok == 0 && falhas == 1 )) && [[ -n $MOTIVO ]]; then
  tit="Não foi possível converter"
  det="$MOTIVO"
else
  tit="$ok convertido(s), $falhas com erro"
  det="${MOTIVO:-Detalhes em ~/Library/Logs/Converter.log}"
fi
(( pulados )) && det+=" · $pulados ignorado(s)"

terminou=1
if [[ -n $SEM_JANELA ]]; then
  # textos vão como argumentos, nunca dentro do código AppleScript (nome de arquivo pode ter aspas)
  [[ -n $SEM_AVISO ]] || osascript -e 'on run argv' \
    -e 'display notification (item 1 of argv) with title "Converter" subtitle (item 2 of argv) sound name "Glass"' \
    -e 'end run' -- "$det" "$tit" >/dev/null
  rm -f "$ST" "$SAIDAS" "$CANCEL"
else
  estado "FIM|$tit|$det"
  # a janela apaga $ST ao ler o FIM; os demais arquivos ficam no TMPDIR até ela fechar
  ( sleep 600; rm -f "$ST" "$SAIDAS" "$CANCEL" ) &!
fi
