# Claude Desktop Profiles

[English](README.md) | **Português (Brasil)** | [Español](README.es.md)

Use **duas ou mais contas do Claude Desktop ao mesmo tempo**, por exemplo uma conta pessoal e uma do trabalho, ou contas de duas empresas diferentes. Cada uma ganha sua própria janela e seu próprio **ícone colorido**.

Chega de sair e entrar de novo para trocar de conta.

| Plataforma | Status | O que você ganha |
|---|---|---|
| **Windows 10/11** | ✅ Testado | Contas separadas lado a lado, atalho colorido na área de trabalho e no menu Iniciar **e botão colorido na barra de tarefas** |
| **macOS** | 🧪 Experimental, não testado | Contas separadas lado a lado e um app de atalho colorido (Dock/Launchpad/Spotlight). A janela aberta continua com o ícone normal do Claude no Dock |

> **Solução alternativa não oficial, feita pela comunidade.** Não é afiliada, endossada nem suportada pela Anthropic. Ela usa comportamentos padrão do Electron e do sistema operacional, não um recurso documentado do Claude, então uma atualização do app pode quebrá-la. O suporte nativo a várias contas foi pedido em [anthropics/claude-code#36821](https://github.com/anthropics/claude-code/issues/36821).

## Como funciona

- Cada perfil é uma instância separada do Claude Desktop, aberta com a opção `--user-data-dir` do Electron. Por isso cada uma tem **seu próprio login, configurações e histórico**. Seu Claude Desktop normal não é alterado e continua sendo sua conta "principal".
- O ícone colorido é gerado **no seu computador**, a partir do Claude instalado, mudando o tom da cor. Nada é baixado.
- No Windows, o atalho também dá à janela do perfil uma identidade própria na barra de tarefas (AppUserModelID), para que ela tenha seu próprio botão colorido.

---

## Windows

### Requisitos

- Windows 10 ou 11
- Claude Desktop instalado pelo [claude.ai/download](https://claude.ai/download) ou pela Microsoft Store
- Windows PowerShell 5.1 (já vem no Windows)

Testado no Windows 11 com o Claude Desktop 4.23118 (versão da Microsoft Store/MSIX). O instalador clássico é suportado pelo script, mas foi menos testado. Relatos são bem-vindos.

### Criar um perfil

1. Baixe o [`claude-profile.ps1`](claude-profile.ps1) e leia o conteúdo. Sempre leia scripts antes de executá-los.
2. Abra o PowerShell na pasta onde você salvou o arquivo e rode:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\claude-profile.ps1 -Install -Name Trabalho -Color blue
   ```

   - `-Name`: só letras sem acento, números, `-` e `_` (ex.: `Trabalho`, `EmpresaX`, `Pessoal`).
   - `-Color`: veja [Cores](#colors).

   Isso cria um atalho **Claude (Trabalho)** na área de trabalho e no menu Iniciar. Também copia o script para `%LOCALAPPDATA%\ClaudeProfiles\`, então os atalhos continuam funcionando mesmo se você apagar o arquivo baixado.

3. Repita com outro nome para cada conta extra.
4. Abra o **Claude (Trabalho)** e [entre na conta](#sign-in-important).

### Uso no dia a dia

- Abra cada conta pelo seu atalho. O app principal e todos os perfis podem ficar abertos ao mesmo tempo.
- **Barra de tarefas:** alguns segundos depois de abrir, o botão do perfil na barra de tarefas muda para a cor dele e se separa do botão do Claude principal.
- **Fixar:** clique com o botão direito no *botão colorido* do perfil aberto e escolha **Fixar na barra de tarefas**. O botão fixado mantém a cor e abre aquele perfil.
- Se a janela de um perfil for aberta de outro jeito (sem ser pelo atalho ou pelo botão fixado), ela pode aparecer com o ícone padrão. Abra pelo atalho de novo para corrigir.

### Outros comandos

```powershell
$cp = "$env:LOCALAPPDATA\ClaudeProfiles\claude-profile.ps1"

powershell -ExecutionPolicy Bypass -File $cp -List                                   # listar perfis
powershell -ExecutionPolicy Bypass -File $cp -Install -Name Trabalho -Color purple    # mudar a cor (mantém o login)
powershell -ExecutionPolicy Bypass -File $cp -Uninstall -Name Trabalho                # remover atalhos, manter o login
powershell -ExecutionPolicy Bypass -File $cp -Uninstall -Name Trabalho -RemoveData    # remover tudo desse perfil
powershell -ExecutionPolicy Bypass -File $cp -Name Trabalho -OpenUrl "claude://..."   # enviar um link de login para esse perfil
```

Feche a janela do perfil (e saia dele pela bandeja do sistema) antes de desinstalar.

Depois de mudar a cor, abra o perfil pelo atalho de novo. Se você fixou o perfil na barra de tarefas, desafixe e fixe de novo, porque o Windows guarda em cache os ícones fixados.

### Onde ficam os dados

| | Local |
|---|---|
| Script e ícones | `%LOCALAPPDATA%\ClaudeProfiles\` |
| Dados do perfil (versão da Store) | `%LOCALAPPDATA%\Packages\Claude_<id>\LocalCache\Roaming\Claude-<Nome>` (o Windows redireciona os dados de apps da Store) |
| Dados do perfil (instalador clássico) | `%APPDATA%\Claude-<Nome>` |

---

## macOS (experimental)

> 🧪 **Não testado.** O script de macOS usa o mesmo mecanismo do Electron que o de Windows, mas ainda não foi executado em um Mac. Se você testar, envie um [relatório de teste no macOS](../../issues/new?template=macos_test_report.yml), mesmo que tudo tenha funcionado.

<a id="what-to-expect"></a>
### O que esperar

- ✅ Contas separadas lado a lado (cada perfil é uma instância própria do Claude, com sua própria pasta de dados).
- ✅ Um app de atalho **Claude (Trabalho).app** em `~/Applications` com ícone colorido, que você pode deixar no Dock ou abrir pelo Spotlight/Launchpad.
- ❌ **A janela aberta continua mostrando o ícone laranja normal do Claude no Dock.** O macOS não deixa outro programa mudar o ícone de um app que já está rodando no Dock. Para isso seria preciso modificar o próprio Claude.app, o que quebra a assinatura e as atualizações, então este projeto não faz isso. Diferencie as janelas pela conta mostrada dentro do app.

### Criar um perfil

```bash
curl -O https://raw.githubusercontent.com/pdmoura/claude-desktop-profiles/main/claude-profile.sh
less claude-profile.sh           # leia antes
chmod +x claude-profile.sh
./claude-profile.sh install Trabalho blue
```

Depois abra o **Claude (Trabalho)** pelo Spotlight, pelo Launchpad ou por `~/Applications`, arraste para o Dock se quiser e [entre na conta](#sign-in-important).

### Outros comandos

```bash
cp="$HOME/Library/Application Support/ClaudeProfiles/claude-profile.sh"

"$cp" list                                 # listar perfis
"$cp" install Trabalho purple              # mudar a cor (mantém o login)
"$cp" launch Trabalho                      # abrir sem o app de atalho
"$cp" uninstall Trabalho                   # remover o atalho, manter o login
"$cp" uninstall Trabalho --remove-data     # remover tudo desse perfil
"$cp" launch Trabalho "claude://..."       # tentar enviar um link de login para esse perfil (não verificado no macOS)
```

Os dados do perfil ficam em `~/Library/Application Support/Claude-<Nome>`.

### Requisitos

macOS com o Claude Desktop em `/Applications` ou `~/Applications`. Só são usadas ferramentas que já vêm no sistema (`open`, `sips`, `iconutil`, `osascript`/Core Image).

---

<a id="sign-in-important"></a>
## Entrar na conta (importante)

Vale para todas as plataformas. Abra o perfil e então:

1. Clique em **Continue with email** (ou a opção de e-mail equivalente, se o app estiver em português). Não use "Continue with Google".
2. Digite o e-mail da conta (endereços do Gmail e do Google Workspace também funcionam).
3. **Digite o código** que chegar por e-mail no app. Não clique no link do e-mail.

**Por quê:** o login com Google e o link do e-mail voltam para o app por um link `claude://`. O sistema operacional entrega esse link para o seu Claude *principal*, e a janela do perfil fica esperando para sempre. O código por e-mail mantém todo o login dentro da janela do perfil. Você só faz isso uma vez, e o perfil continua conectado.

Se a sua empresa só permite login com Google/SSO, copie o link `claude://...` no navegador em vez de deixá-lo abrir o Claude, e passe-o para o perfil com o comando `-OpenUrl` (Windows) ou `launch Trabalho "claude://..."` (macOS) mostrados acima.

<a id="colors"></a>
## Cores

`red` (vermelho), `orange` (laranja), `yellow` (amarelo), `green` (verde), `teal` (verde-azulado), `blue` (azul), `indigo` (índigo), `purple` (roxo), `pink` (rosa), ou qualquer número de matiz de `0` a `360` (por exemplo `195` para azul-celeste ou `300` para magenta). Use os nomes em inglês no comando.

A cor é uma mudança de matiz do logo do Claude, então mantém o brilho e a saturação originais. Preto, branco, cinza e cores exatas em hexadecimal não são suportados.

## Limitações

- Não oficial: uma atualização do Claude Desktop pode mudar esse comportamento.
- Cada perfil é uma instância completa do app, então usa tanta memória quanto uma segunda janela do Claude.
- Windows: o Alt+Tab ainda pode mostrar o ícone padrão do Claude. Um pequeno processo oculto do PowerShell roda por alguns segundos quando um perfil abre (para definir o ícone da barra de tarefas) e depois fecha.
- macOS: veja [O que esperar](#what-to-expect).

## Como contribuir

Relatos de bugs, relatórios de teste no macOS e pull requests são bem-vindos. Veja o [CONTRIBUTING.md](CONTRIBUTING.md) (em inglês) para saber como as mudanças são revisadas e aceitas, e o [SECURITY.md](SECURITY.md) para relatar uma vulnerabilidade de forma privada. Issues e pull requests podem ser escritos em português, inglês ou espanhol.

## Licença

MIT. Veja [LICENSE](LICENSE).
