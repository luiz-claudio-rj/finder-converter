# Converter para Mac

Converta vídeo, áudio e imagem com o botão direito no Finder: **Ações Rápidas → Converter…**
Grátis, de código aberto e sem enviar nada para a internet.

**Página do projeto:** https://luiz-claudio-rj.github.io/finder-converter/

![Menu do Finder com a opção Converter e a janela de progresso mostrando Pronto](docs/og.png)

## O que ele faz

| Arquivo | Converte para |
|---|---|
| Vídeo (MOV, MKV, AVI, WebM, GIF…) | MP4 (H.264), MP4 comprimido (HEVC), MOV, WebM, GIF, MP3 ou M4A (só o áudio) |
| Áudio (WAV, M4A, AIFF, FLAC, OGG…) | MP3, M4A, WAV, FLAC, OGG |
| Imagem (HEIC, PNG, JPG, TIFF, WebP…) | JPG, PNG, WebP, HEIC, AVIF, PDF |

- **Tamanho**: vídeo em 4K, 1080p, 720p ou 480p; imagem pelo lado maior (4096 a 512 px). Nunca aumenta um arquivo menor.
- **Qualidade**: alta, média ou baixa (arquivo menor). Formatos sem perda (WAV, FLAC, PNG, PDF) usam sempre a máxima.
- **Vídeo HDR do iPhone**: detecta o HDR e ajusta as cores para SDR com o `avconvert` da Apple antes de converter, para o vídeo não sair lavado. Ignora a trilha de áudio espacial (APAC), que o ffmpeg não lê.
- **Janela de progresso**: mostra cada passo ("Passo 1 de 2: ajustando as cores"), a porcentagem e o tempo restante, com botão Cancelar.
- **Resultado ao lado do original**, com o mesmo nome. Se já existir, vira `nome (1).ext`. O original nunca é alterado.
- Lembra a última escolha para cada tipo de arquivo.

## Instalar

Requisitos: macOS 13 ou mais novo (testado no macOS 26) e [Homebrew](https://brew.sh/pt-br/).

```bash
git clone https://github.com/luiz-claudio-rj/finder-converter.git
cd finder-converter && zsh install.sh
```

O instalador:

1. confere se `ffmpeg`, `ffprobe` e `cwebp` estão instalados e oferece instalar com o Homebrew;
2. copia o `converter.sh` para `~/Library/Application Support/Converter/`;
3. instala a Ação Rápida em `~/Library/Services/Converter.workflow`;
4. liga a ação no menu do Finder e reinicia o Finder.

Se "Converter…" não aparecer: botão direito em qualquer arquivo → Ações Rápidas → Personalizar… e ligue **Converter…**.

## Desinstalar

```bash
zsh uninstall.sh
```

Remove a ação e o script. Não mexe no ffmpeg nem nos seus arquivos.

## Problemas

O motivo de cada falha fica em `~/Library/Logs/Converter.log`.

Para testar sem abrir as janelas:

```bash
SEM_JANELA=1 FORMATO="MP4 (H.264)" TAMANHO="720p (HD)" QUALIDADE="Média" ./converter.sh video.mov
```

## Como funciona

| Arquivo | Papel |
|---|---|
| `converter.sh` | Script principal (zsh). Mostra a janela de opções e a de progresso (JavaScript for Automation com Cocoa) e chama `ffmpeg`, `avconvert`, `sips` e `cwebp`. |
| `workflow/Converter.workflow` | Ação Rápida do Automator que só chama o `converter.sh` instalado. |
| `install.sh` / `uninstall.sh` | Instalação e remoção. |
| `docs/` | Página do projeto (GitHub Pages). |

## Licença

[MIT](LICENSE). Usa [FFmpeg](https://ffmpeg.org) e [libwebp](https://developers.google.com/speed/webp), instalados pelo Homebrew. Não é afiliado à Apple.
