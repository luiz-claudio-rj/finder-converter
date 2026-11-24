#!/bin/zsh
# Remove o Converter. Não mexe no ffmpeg/cwebp nem nos arquivos que você converteu.
# Uso:  ./uninstall.sh

CHAVE="(null) - Converter… - runWorkflowAsService"

rm -rf "$HOME/Library/Services/Converter.workflow" "$HOME/Library/Services/Converter….workflow"
rm -rf "$HOME/Library/Application Support/Converter"
# tira o "ligado" da ação (passa pelo defaults para o macOS não sobrescrever a mudança)
TMP=$(mktemp -t converter-pbs).plist
if defaults export pbs "$TMP" 2>/dev/null \
   && /usr/libexec/PlistBuddy -c "Delete :NSServicesStatus:'$CHAVE'" "$TMP" 2>/dev/null; then
  defaults import pbs "$TMP"
fi
rm -f "$TMP"
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1
/System/Library/CoreServices/pbs -update >/dev/null 2>&1
killall Finder 2>/dev/null

echo "Converter removido. O registro de conversões continua em ~/Library/Logs/Converter.log (pode apagar)."
