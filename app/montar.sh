#!/bin/zsh
# Monta o Converter.app com o osacompile (já vem no macOS, não precisa do Xcode).
# Uso: zsh app/montar.sh <destino/Converter.app>
# O app é montado no próprio Mac, por isso abre sem o aviso de "app não verificado".
set -e
APP="$1"; AQUI="${0:A:h}"; RAIZ="${AQUI:h}"
[[ $APP == *.app ]] || { echo "Uso: zsh app/montar.sh <destino/Converter.app>" >&2; exit 1; }

rm -rf "$APP"
osacompile -l JavaScript -s -o "$APP" "$AQUI/Converter.js" 2>/dev/null

REC="$APP/Contents/Resources"; PL="$APP/Contents/Info.plist"
# cat em vez de cp: não carrega a marca de quarentena do download para dentro do app
cat "$RAIZ/converter.sh" > "$REC/converter.sh"; chmod 755 "$REC/converter.sh"
rm -f "$REC/Assets.car" "$REC"/*.icns
cat "$AQUI/Converter.icns" > "$REC/Converter.icns"

por() { plutil -replace "$@" "$PL"; }
plutil -remove CFBundleIconName "$PL" 2>/dev/null || true
for k in AppleEvents AppleMusic Calendars Camera Contacts HomeKit Microphone PhotoLibrary Reminders Siri SystemAdministration; do
  plutil -remove "NS${k}UsageDescription" "$PL" 2>/dev/null || true   # o applet padrão declara; o Converter não usa
done
por CFBundleIdentifier -string io.github.luiz-claudio-rj.converter
por CFBundleName -string Converter
por CFBundleIconFile -string Converter
por CFBundleDevelopmentRegion -string pt_BR
por CFBundleShortVersionString -string "$(<"$RAIZ/VERSION")"
por CFBundleVersion -string "$(<"$RAIZ/VERSION")"
por LSMinimumSystemVersion -string 13.0
por LSApplicationCategoryType -string public.app-category.utilities
por NSHumanReadableCopyright -string "Licença MIT"
for k in Desktop Documents Downloads; do
  por "NS${k}FolderUsageDescription" -string "Para ler o arquivo e salvar o convertido ao lado dele."
done
por NSRemovableVolumesUsageDescription -string "Para ler o arquivo e salvar o convertido ao lado dele."
# "Abrir com" e ícone do Dock. Alternate: nunca vira o programa padrão dos arquivos.
por CFBundleDocumentTypes -json '[
  {"CFBundleTypeName":"Vídeo, áudio ou imagem","CFBundleTypeRole":"Viewer","LSHandlerRank":"Alternate",
   "LSItemContentTypes":["public.movie","public.audio","public.image"]},
  {"CFBundleTypeName":"Vídeo ou áudio","CFBundleTypeRole":"Viewer","LSHandlerRank":"Alternate",
   "CFBundleTypeExtensions":["mkv","webm","wmv","flv","avi","ogg","opus","wma","flac","mts","m2ts"]}]'
codesign --force --sign - "$APP" 2>/dev/null
