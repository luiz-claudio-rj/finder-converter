# Envio para o Homebrew oficial (homebrew/core)

Rascunho e passo a passo para colocar o Converter no Homebrew oficial, que é o que aparece em
[formulae.brew.sh](https://formulae.brew.sh). Enquanto isso não acontece, a instalação é pelo tap
próprio: `brew install luiz-claudio-rj/tap/finder-converter`.

## Quando dá para enviar

Regras da [política de aceitação do Homebrew](https://docs.brew.sh/Package-Acceptance-Policy):

| Regra | Como está |
|---|---|
| Repositório com **pelo menos 30 dias** | Criado em 23/11/2026, então pode a partir de **23/12/2026** |
| Enviado pelo próprio autor: **225 estrelas**, ou 90 forks, ou 90 watchers | Acompanhar no GitHub |
| Enviado por **outra pessoa**: 75 estrelas, ou 30 forks, ou 30 watchers | Alternativa, se um usuário quiser enviar |
| Versão estável com tag e checksum | Pronto (tags `vX.Y.Z`) |
| `livecheck` funcionando | Pronto |
| Teste que exercita o programa | Pronto: converte um WAV em MP3 |
| Sem passos manuais extensos depois de instalar | `finder-converter setup` é um comando só, mas pode ser questionado na revisão |

Cumprir as regras não garante a aceitação: os revisores avaliam caso a caso.

## Passo a passo

1. Atualize a fórmula `finder-converter.rb` desta pasta para a versão mais recente:
   ```bash
   V=1.2.1   # versão atual
   SHA=$(curl -sL https://github.com/luiz-claudio-rj/finder-converter/archive/refs/tags/v$V.tar.gz | shasum -a 256 | cut -d' ' -f1)
   sed -i '' "s|/v[0-9.]*\.tar\.gz|/v$V.tar.gz|; s|sha256 \".*\"|sha256 \"$SHA\"|" finder-converter.rb
   ```
2. Valide localmente, como o Homebrew vai fazer:
   ```bash
   brew tap-new local/teste --no-git
   brew trust local/teste   # o Homebrew só carrega fórmulas de taps marcados como confiáveis
   cp finder-converter.rb "$(brew --repo local/teste)/Formula/"
   brew install --build-from-source local/teste/finder-converter
   brew test local/teste/finder-converter
   brew audit --strict --new --online local/teste/finder-converter
   brew uninstall finder-converter && brew untap local/teste
   ```
3. Faça um fork de [Homebrew/homebrew-core](https://github.com/Homebrew/homebrew-core) com a conta
   `luiz-claudio-rj`, copie a fórmula para `Formula/f/finder-converter.rb` e abra o pull request
   com o título `finder-converter 1.2.1 (new formula)`.
4. Se for aceito, troque nos READMEs e na página `brew install luiz-claudio-rj/tap/finder-converter`
   por `brew install finder-converter`, e mantenha o tap só para quem já instalou por ele.

## Alternativa: cask

Os casks do Homebrew têm o artefato `service`, que instala Ações Rápidas direto em
`~/Library/Services`. Isso poderia eliminar o `finder-converter setup`. As regras de popularidade
são as mesmas. Vale avaliar se o pull request da fórmula for recusado pelo passo de setup.
