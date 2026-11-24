#!/bin/zsh
# Instala o Converter: botão direito no Finder → Ações Rápidas → Converter…
# Uso:  ./install.sh
set -e
cd "${0:A:h}"

DESTINO="$HOME/Library/Application Support/Converter"
SERVICOS="$HOME/Library/Services"
CHAVE="(null) - Converter… - runWorkflowAsService"   # nome que o macOS usa para ligar/desligar a ação

verde() { print -P "%F{green}✓%f $1"; }
aviso() { print -P "%F{yellow}!%f $1"; }
erro()  { print -P "%F{red}✗%f $1"; }

[[ $(uname) == Darwin ]] || { erro "O Converter só funciona no macOS."; exit 1; }

# 1. Dependências: ffmpeg/ffprobe (vídeo e áudio) e cwebp (WebP). sips e avconvert já vêm no macOS.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
faltando=()
command -v ffmpeg  >/dev/null || faltando+=(ffmpeg)
command -v ffprobe >/dev/null || faltando+=(ffmpeg)
command -v cwebp   >/dev/null || faltando+=(webp)
faltando=(${(u)faltando})

if (( $#faltando )); then
  aviso "Faltam programas: ${faltando[*]}"
  if command -v brew >/dev/null; then
    read -q "resp?Instalar com o Homebrew agora (brew install ${faltando[*]})? [s/N] " || true
    echo
    if [[ $resp == s ]]; then
      brew install ${faltando[@]}
    else
      erro "Instale com: brew install ${faltando[*]} e rode o install.sh de novo."; exit 1
    fi
  else
    erro "Instale o Homebrew (https://brew.sh) e depois: brew install ${faltando[*]}"; exit 1
  fi
fi
verde "ffmpeg, ffprobe e cwebp encontrados"

# 2. Script principal. Pelo Homebrew vira um atalho para a versão do brew, assim
#    "brew upgrade" atualiza o Converter sem precisar rodar o setup de novo.
mkdir -p "$DESTINO"
rm -f "$DESTINO/converter.sh"
if [[ -n $CONVERTER_BREW_LIBEXEC ]]; then
  ln -s "$CONVERTER_BREW_LIBEXEC/converter.sh" "$DESTINO/converter.sh"
  verde "Script ligado à versão do Homebrew"
else
  cp converter.sh "$DESTINO/converter.sh"
  chmod +x "$DESTINO/converter.sh"
  verde "Script instalado em ~/Library/Application Support/Converter"
fi

# 3. Ação Rápida (remove versões antigas, inclusive a que embutia o script)
mkdir -p "$SERVICOS"
rm -rf "$SERVICOS/Converter.workflow" "$SERVICOS/Converter….workflow"
cp -R workflow/Converter.workflow "$SERVICOS/"
verde "Ação Rápida instalada em ~/Library/Services/Converter.workflow"

# 4. Liga a ação no menu de contexto e nas Ações Rápidas do Finder
defaults write pbs NSServicesStatus -dict-add "\"$CHAVE\"" \
  '<dict><key>presentation_modes</key><dict>
     <key>ContextMenu</key><true/><key>FinderPreview</key><true/>
     <key>ServicesMenu</key><true/><key>TouchBar</key><false/>
   </dict></dict>'
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
verde "Ação ativada no Finder"

# 5. O Finder só lê a lista de ações ao abrir
killall Finder 2>/dev/null || true
verde "Finder reiniciado"

echo
print -P "%BPronto!%b Clique com o botão direito em um vídeo, áudio ou imagem e escolha"
print -P "%BAções Rápidas → Converter…%b"
echo
echo "Se não aparecer: botão direito → Ações Rápidas → Personalizar… e ligue \"Converter…\"."
