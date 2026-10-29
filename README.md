# PodsMic

App de barra de menus para macOS: apertar a haste dos AirPods alterna o microfone do Google Meet aberto no navegador. O ícone mostra o estado do microfone.

Requer macOS 14 ou mais recente e AirPods compatíveis com o gesto de mudo em chamadas (apertar a haste).

## Instalação

1. Baixe o `PodsMic-<versão>.dmg` na [última release](../../releases/latest), abra e arraste o PodsMic para *Aplicativos*.
2. O app não é notarizado pela Apple, então na primeira abertura o macOS bloqueia. Vá em
   *Ajustes do Sistema › Privacidade e Segurança*, clique em **Abrir Mesmo Assim** e confirme.
   (Alternativa no Terminal: `xattr -dr com.apple.quarantine /Applications/PodsMic.app`.)

## Build

```bash
make            # gera build/PodsMic.app (Apple Silicon + Intel)
make install    # copia para ~/Applications e abre
make dmg        # gera build/PodsMic-<versão>.dmg
make icon       # regenera Resources/AppIcon.icns
make clean
```

A versão vem da última tag do git (`v1.2.0` → `1.2.0`), ou de `make dmg VERSION=1.2.0`.

## Release

Publicar uma release no GitHub com uma tag `vX.Y.Z` dispara o workflow
[`release.yml`](.github/workflows/release.yml), que roda `make dmg` e anexa o `.dmg` à release.

## Configuração (uma vez)

1. **Permitir JavaScript de Apple Events** no navegador:
   - Chrome / Brave / Edge: menu *Visualizar › Desenvolvedor › Permitir JavaScript de Apple Events*
   - Safari: menu *Desenvolvedor › Permitir JavaScript de Apple Events*
2. Na primeira execução, aceite os pedidos para o PodsMic controlar o navegador e usar o microfone
   (ou libere em *Ajustes do Sistema › Privacidade e Segurança › Automação / Microfone*).

## Como funciona

- A cada segundo o app lê, via AppleScript, o botão de microfone da aba `meet.google.com` (atributo `data-is-muted`).
- Com o microfone em uso, apertar a haste não manda play/pause: os AirPods mandam um comando de mudo, que o `audioaccessoryd` repassa ao `audiomxd`. Ele entrega o gesto, via `AVAudioApplication`, só a apps que estejam gravando **e** inscritos no gesto. O Chrome não é inscrito, então sem um app inscrito o macOS toca o som de "não foi possível".
- Enquanto há uma reunião aberta, o PodsMic:
  1. observa `AVAudioApplication.inputMuteStateChangeNotification` com `object: AVAudioApplication.shared`, que é o que inscreve o app (o `audiomxd` marca `PrefersBluetoothAccessoryMutingMacOS`). Com `object: nil` a inscrição não acontece;
  2. abre o microfone (sem gravar nada) para ser um app "gravando";
  3. registra `setInputMuteStateChangeHandler`. O toque na haste chama o handler, e o app clica no botão de microfone do Meet.

Para depurar:

```bash
/usr/bin/log stream --predicate 'subsystem == "com.bigotto.PodsMic" OR (process == "audiomxd" AND composedMessage CONTAINS[c] "input mute")'
```

Ícone do app: `Resources/AppIcon.icns`, gerado por `make icon`.

Ícones da barra de menus: `mic.fill` = ligado, `mic.slash.fill` = mudo, `mic.slash` esmaecido = sem reunião.

Obs.: o build usa assinatura ad-hoc; após recompilar, o macOS pode pedir as permissões de Automação e Microfone de novo.
