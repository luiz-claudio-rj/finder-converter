// Converter.app — janela para soltar arquivos e o painel "Apoie".
// Não converte nada: entrega os arquivos ao converter.sh (Contents/Resources), o mesmo da Ação
// Rápida do Finder. Montado por app/montar.sh com o osacompile, que já vem no macOS.
ObjC.import('Cocoa');
ObjC.import('CoreImage');

const SITE = 'https://luiz-claudio-rj.github.io/finder-converter/';
const SPONSORS = 'https://github.com/sponsors/luiz-claudio-rj';
// "copia e cola" do Pix: o mesmo código da página do projeto
const PIX = '00020126580014br.gov.bcb.pix0136a25659b7-1c09-4fa6-905a-9b8ecd2c68b1'
          + '5204000053039865802BR5912Luiz Claudio6011Sao Goncalo62070503***6304898F';
const PIX_CONFIRA = 'No banco vai aparecer:\nLuiz Claudio Lessa Vargas Junior\nMercado Pago';

const CASA = ObjC.unwrap($.NSHomeDirectory());
const PREFS = CASA + '/Library/Application Support/Converter';
const PEDIDO_APOIE = PREFS + '/mostrar-apoie';   // criado pelo converter.sh para abrir o painel
const ACAO = CASA + '/Library/Services/Converter.workflow';
const W = 460, H = 400, RODAPE = 74;

let win = null, v, ctl, area, aviso, dicaFinder, contador, painel = null, bCopiar = null;

const fm = () => $.NSFileManager.defaultManager;
const existe = p => fm().fileExistsAtPath(p);
const temPrograma = n => ['/opt/homebrew/bin/', '/usr/local/bin/'].some(d => existe(d + n));
const abrirURL = u => $.NSWorkspace.sharedWorkspace.openURL($.NSURL.URLWithString(u));
function ler(p) {
  const s = $.NSString.stringWithContentsOfFileEncodingError(p, 4, null);
  return s.isNil() ? '' : ObjC.unwrap(s).trim();
}

// ───────────────────────── conversão ─────────────────────────
function converter(caminhos) {
  if (!caminhos.length) return;
  const t = $.NSTask.alloc.init;
  const script = ObjC.unwrap($.NSBundle.mainBundle.pathForResourceOfType('converter', 'sh'));
  t.launchPath = '/bin/zsh';
  t.arguments = $([script].concat(caminhos));
  const amb = $.NSMutableDictionary.dictionaryWithDictionary($.NSProcessInfo.processInfo.environment);
  amb.setObjectForKey($('1'), $('CONV_SEPARAR'));   // tipos misturados: uma janela de opções por tipo
  t.environment = amb;
  t.launch;
}

function escolher() {
  const p = $.NSOpenPanel.openPanel;
  p.allowsMultipleSelection = true;
  p.canChooseDirectories = false;
  p.message = 'Escolha vídeos, áudios ou imagens';
  p.prompt = 'Escolher';
  p.allowedFileTypes = $(['public.movie', 'public.audio', 'public.image', 'mkv', 'webm', 'wmv', 'flv', 'avi',
                         'ogg', 'opus', 'wma', 'flac', 'mts', 'm2ts', 'ts']);
  if (p.runModal !== 1) return;
  const urls = p.URLs, lista = [];
  for (let i = 0; i < urls.count; i++) lista.push(ObjC.unwrap(urls.objectAtIndex(i).path));
  converter(lista);
}

// ───────────────────────── classes ─────────────────────────
function registrar() {
  ObjC.registerSubclass({
    name: 'ConvAreaSoltar', superclass: 'NSBox',
    methods: {
      'draggingEntered:': { types: ['unsigned long', ['id']], implementation: function () {
        realcar(true); return 1;                      // NSDragOperationCopy
      } },
      'draggingUpdated:': { types: ['unsigned long', ['id']], implementation: function () { return 1; } },
      'draggingExited:': { types: ['void', ['id']], implementation: function () { realcar(false); } },
      'prepareForDragOperation:': { types: ['bool', ['id']], implementation: function () { return true; } },
      'performDragOperation:': { types: ['bool', ['id']], implementation: function (info) {
        realcar(false);
        const l = info.draggingPasteboard.propertyListForType('NSFilenamesPboardType');
        if (l.isNil()) return false;
        converter(ObjC.deepUnwrap(l));
        return true;
      } },
    },
  });
  ObjC.registerSubclass({
    name: 'ConvCtl',
    protocols: ['NSWindowDelegate'],
    methods: {
      'escolher:': { types: ['void', ['id']], implementation: function () { escolher(); } },
      'apoiar:': { types: ['void', ['id']], implementation: function () { mostrarApoie(); } },
      'site:': { types: ['void', ['id']], implementation: function () { abrirURL(SITE); } },
      'sponsors:': { types: ['void', ['id']], implementation: function () { abrirURL(SPONSORS); } },
      'fecharApoie:': { types: ['void', ['id']], implementation: function () {
        painel.orderOut(null);
      } },
      'copiarPix:': { types: ['void', ['id']], implementation: function () {
        const pb = $.NSPasteboard.generalPasteboard;
        pb.clearContents;
        pb.setStringForType($(PIX), $.NSPasteboardTypeString);
        bCopiar.title = 'Código copiado ✓';
      } },
      'tick:': { types: ['void', ['id']], implementation: function () { atualizar(); atenderPedido(); } },
      'windowWillClose:': { types: ['void', ['id']], implementation: function () { $.NSApp.terminate(null); } },
    },
  });
  ctl = $.ConvCtl.alloc.init;
}

// ───────────────────────── janela ─────────────────────────
function texto(onde, txt, x, y, w, h, size, o) {
  o = o || {};
  const t = o.quebra ? $.NSTextField.wrappingLabelWithString(txt) : $.NSTextField.labelWithString(txt);
  t.frame = $.NSMakeRect(x, y, w, h);
  t.font = o.peso ? $.NSFont.systemFontOfSizeWeight(size, o.peso) : $.NSFont.systemFontOfSize(size);
  if (o.cor) t.textColor = o.cor;
  onde.addSubview(t);
  if (o.centro) centrar(t, x, w);
  return t;
}
// Centraliza pela largura do texto: o valor de NSTextAlignmentCenter muda entre Intel e Apple Silicon.
function centrar(t, x, w) {
  t.sizeToFit;
  const f = t.frame;
  t.frame = $.NSMakeRect(x + (w - f.size.width) / 2, f.origin.y, f.size.width, f.size.height);
}
function botao(onde, nome, acao, x, y, w) {
  const b = $.NSButton.buttonWithTitleTargetAction(nome, ctl, acao);
  b.frame = $.NSMakeRect(x, y, w, 32);
  onde.addSubview(b);
  return b;
}
function realcar(sim) {
  area.borderColor = sim ? $.NSColor.controlAccentColor : $.NSColor.separatorColor;
  area.borderWidth = sim ? 3 : 1.5;
}

function montarJanela() {
  if (win) return;
  registrar();
  const app = $.NSApplication.sharedApplication;
  app.setActivationPolicy($.NSApplicationActivationPolicyRegular);
  const cinza = $.NSColor.secondaryLabelColor;

  // 1 = com título, 2 = fechar, 4 = minimizar
  win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer($.NSMakeRect(0, 0, W, H), 7, 2, false);
  win.title = 'Converter';
  win.releasedWhenClosed = false;
  win.delegate = ctl;
  v = win.contentView;

  // área de soltar
  const ax = 20, ay = RODAPE + 54, aw = W - 40, ah = H - ay - 20;
  area = $.ConvAreaSoltar.alloc.initWithFrame($.NSMakeRect(ax, ay, aw, ah));
  area.boxType = 4;                                   // NSBoxCustom
  area.titlePosition = 0;
  area.cornerRadius = 14;
  area.fillColor = $.NSColor.controlBackgroundColor;
  realcar(false);
  area.registerForDraggedTypes($(['NSFilenamesPboardType']));
  v.addSubview(area);
  const a = area.contentView;
  const icone = $.NSImageView.imageViewWithImage(app.applicationIconImage);
  icone.frame = $.NSMakeRect((aw - 84) / 2, ah - 120, 84, 84);
  icone.unregisterDraggedTypes;                       // a imagem não pode capturar o arquivo solto
  a.addSubview(icone);
  texto(a, 'Solte vídeos, áudios ou imagens aqui', 0, ah - 156, aw, 22, 15, { centro: true, peso: 0.3 });
  aviso = texto(a, '', 0, 14, aw, 16, 11, { cor: $.NSColor.systemRedColor });
  const b = botao(a, 'Escolher arquivos…', 'escolher:', (aw - 170) / 2, ah - 206, 170);
  b.keyEquivalent = '\r';

  dicaFinder = texto(v, 'Também no Finder: botão direito → Ações Rápidas → Converter…',
                     20, RODAPE + 20, W - 40, 18, 12, { centro: true, cor: cinza });

  // rodapé com o Apoie
  const risco = $.NSBox.alloc.initWithFrame($.NSMakeRect(0, RODAPE, W, 1));
  risco.boxType = 2;                                  // NSBoxSeparator
  v.addSubview(risco);
  texto(v, 'Grátis e de código aberto', 20, 37, 250, 18, 13, { peso: 0.23 });
  contador = texto(v, '', 20, 18, 250, 16, 11, { cor: cinza });
  botao(v, '♥ Apoiar o projeto', 'apoiar:', W - 178, 20, 160);

  atualizar();
  $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(1, ctl, 'tick:', null, true);
  win.center;
}

function atualizar() {
  const n = parseInt(ler(PREFS + '/total')) || 0;
  const versao = 'v' + ObjC.unwrap($.NSBundle.mainBundle.objectForInfoDictionaryKey('CFBundleShortVersionString'));
  contador.stringValue = n === 0 ? versao
    : 'Você já converteu ' + (n === 1 ? '1 arquivo' : n.toLocaleString('pt-BR') + ' arquivos') + ' · ' + versao;
  const faltam = ['ffmpeg', 'ffprobe', 'cwebp'].filter(p => !temPrograma(p))
    .map(p => p === 'cwebp' ? 'webp' : 'ffmpeg').filter((p, i, l) => l.indexOf(p) === i);
  aviso.stringValue = faltam.length ? 'Falta instalar. No Terminal: brew install ' + faltam.join(' ') : '';
  centrar(aviso, 0, W - 40);
  dicaFinder.hidden = !existe(ACAO);
}

// O "♥ Apoiar o projeto" da janela de Pronto deixa este pedido para o app abrir o painel.
function atenderPedido() {
  if (!existe(PEDIDO_APOIE)) return;
  fm().removeItemAtPathError(PEDIDO_APOIE, null);
  win.makeKeyAndOrderFront(null);
  mostrarApoie();
}

function mostrar() {
  montarJanela();
  win.makeKeyAndOrderFront(null);
  $.NSApp.activateIgnoringOtherApps(true);
  atenderPedido();
}

// ───────────────────────── painel Apoie ─────────────────────────
function imagemPix(lado) {
  const f = $.CIFilter.filterWithName('CIQRCodeGenerator');
  f.setDefaults;
  f.setValueForKey($(PIX).dataUsingEncoding(4), 'inputMessage');
  f.setValueForKey($('M'), 'inputCorrectionLevel');
  const img = f.outputImage.imageByApplyingTransform($.CGAffineTransformMakeScale(8, 8));
  const rep = $.NSCIImageRep.imageRepWithCIImage(img);
  const ns = $.NSImage.alloc.initWithSize($.NSMakeSize(lado, lado));
  ns.addRepresentation(rep);
  return ns;
}

function mostrarApoie() {
  if (!painel) montarApoie();
  bCopiar.title = 'Copiar código Pix';
  const f = win.frame;                     // centralizado sobre a janela principal
  painel.setFrameOrigin($.NSMakePoint(f.origin.x + (f.size.width - painel.frame.size.width) / 2,
                                      f.origin.y + (f.size.height - painel.frame.size.height) / 2));
  painel.makeKeyAndOrderFront(null);
}

function montarApoie() {
  const PW = 460, PH = 290, QR = 168;
  // janela própria, e não "sheet": encerrar um sheet pelo JXA falha
  painel = $.NSPanel.alloc.initWithContentRectStyleMaskBackingDefer($.NSMakeRect(0, 0, PW, PH), 3, 2, false);
  painel.title = 'Apoie o Converter';
  painel.releasedWhenClosed = false;
  const p = painel.contentView, cinza = $.NSColor.secondaryLabelColor;
  texto(p, 'Obrigado por usar o Converter', 24, PH - 46, PW - 48, 24, 17, { peso: 0.4 });
  texto(p, 'O Converter é grátis e vai continuar assim. Se ele te ajudou, você pode agradecer com qualquer valor.',
        24, PH - 84, PW - 48, 34, 12, { quebra: true, cor: cinza });

  // fundo branco fixo: no modo escuro o QR precisa da margem clara para ser lido
  const fundo = $.NSBox.alloc.initWithFrame($.NSMakeRect(24, 20, QR + 12, QR + 12));
  fundo.boxType = 4; fundo.titlePosition = 0; fundo.cornerRadius = 10; fundo.borderWidth = 0;
  fundo.contentViewMargins = $.NSMakeSize(0, 0);
  fundo.fillColor = $.NSColor.whiteColor;
  const qr = $.NSImageView.imageViewWithImage(imagemPix(QR));
  qr.frame = $.NSMakeRect(6, 6, QR, QR);
  qr.setAccessibilityLabel('QR Code do Pix para apoiar o Converter');
  fundo.contentView.addSubview(qr);
  p.addSubview(fundo);

  const x = 224, w = PW - x - 24;
  bCopiar = botao(p, 'Copiar código Pix', 'copiarPix:', x - 4, 168, w + 8);
  texto(p, PIX_CONFIRA, x, 116, w, 48, 11, { quebra: true, cor: cinza });
  botao(p, 'GitHub Sponsors', 'sponsors:', x - 4, 76, w + 8);
  const f = botao(p, 'Fechar', 'fecharApoie:', PW - 124, 18, 104);
  f.keyEquivalent = '\u001b';
}

// ───────────────────────── entradas do app ─────────────────────────
function run() { mostrar(); }
function reopen() { mostrar(); }
function openDocuments(docs) {            // ícone do Dock e "Abrir com"
  mostrar();
  converter(docs.map(d => d.toString()));
}
function quit() { return true; }
