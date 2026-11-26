# Envio para o Homebrew oficial (homebrew/cask)

Rascunho e passo a passo para colocar o Converter no Homebrew oficial, que é o que aparece em
[formulae.brew.sh](https://formulae.brew.sh). Enquanto isso não acontece, a instalação é pelo tap
próprio: `brew install luiz-claudio-rj/tap/finder-converter`.

O Converter é distribuído como **cask**, e não como fórmula, porque precisa colocar a Ação Rápida
em `~/Library/Services` e ligá-la no Finder. Fórmulas não podem mexer na pasta do usuário; casks
podem, com o artefato `service`. Assim a instalação é um comando só, sem passo manual.

## Quando dá para enviar

Regras da [política de aceitação do Homebrew](https://docs.brew.sh/Package-Acceptance-Policy):

| Regra | Como está |
|---|---|
| Repositório com **pelo menos 30 dias** | Criado em 23/11/2026, então pode a partir de **23/12/2026** |
| Enviado pelo próprio autor: **225 estrelas**, ou 90 forks, ou 90 watchers | Acompanhar no GitHub |
| Enviado por **outra pessoa**: 75 estrelas, ou 30 forks, ou 30 watchers | Alternativa, se um usuário quiser enviar |
| Versão estável com tag e checksum | Pronto (tags `vX.Y.Z`) |
| `livecheck` funcionando | Pronto |
| Sem passos manuais depois de instalar | Pronto: o cask instala, liga a ação e reinicia o Finder |

Pontos que a revisão pode questionar: o cask grava uma preferência do Finder (`pbs`) para ligar a
ação e reinicia o Finder. Os dois passos são necessários para "Converter…" aparecer no menu sem
intervenção, e ficam explicados nos comentários do cask. Cumprir as regras não garante a aceitação.

## Passo a passo

1. Atualize o cask `finder-converter.rb` desta pasta para a versão mais recente:
   ```bash
   V=1.4.0   # versão atual
   SHA=$(curl -sL https://github.com/luiz-claudio-rj/finder-converter/archive/refs/tags/v$V.tar.gz | shasum -a 256 | cut -d' ' -f1)
   sed -i '' "s|version \".*\"|version \"$V\"|; s|sha256 \".*\"|sha256 \"$SHA\"|" finder-converter.rb
   ```
2. Valide localmente, como o Homebrew vai fazer:
   ```bash
   brew tap-new local/teste --no-git
   brew trust local/teste   # o Homebrew só carrega pacotes de taps marcados como confiáveis
   mkdir -p "$(brew --repo local/teste)/Casks"
   cp finder-converter.rb "$(brew --repo local/teste)/Casks/"
   brew install --cask local/teste/finder-converter
   brew audit --cask --strict --new --online local/teste/finder-converter
   brew uninstall --cask finder-converter && brew untap local/teste
   ```
3. Faça um fork de [Homebrew/homebrew-cask](https://github.com/Homebrew/homebrew-cask) com a conta
   `luiz-claudio-rj`, copie o cask para `Casks/f/finder-converter.rb` e abra o pull request
   com o título `finder-converter 1.4.0 (new cask)`.
4. Se for aceito, troque nos READMEs e na página `brew install luiz-claudio-rj/tap/finder-converter`
   por `brew install --cask finder-converter`, e mantenha o tap só para quem já instalou por ele.
