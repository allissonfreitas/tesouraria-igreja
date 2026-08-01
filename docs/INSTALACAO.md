# Setup passo a passo - Tesouraria da Igreja

Este guia documenta como instalar e publicar uma nova copia do sistema de tesouraria para outra igreja ou unidade, sem reutilizar chaves, dados ou configuracoes de producao de outra instalacao.

O projeto e um aplicativo web estatico em `public/index.html`, com Supabase para banco/Auth/Storage/Edge Functions e Netlify para hospedagem.

## 1. Visao geral

### Recursos principais

- Login por e-mail e senha usando Supabase Auth.
- Perfis de acesso:
  - `admin`: ve dashboard, historico, anexos, Excel, PDF e gerencia funcoes.
  - `lancador`: apenas registra entradas e saidas; nao ve historico nem totais administrativos.
- Registro de entradas de dizimos/ofertas com:
  - foto do relatorio de receitas;
  - OCR/IA via Gemini para preencher campos;
  - data, hora, unidade, numero do relatorio, lacre, pessoas e responsaveis;
  - dinheiro, VR/recibos, Pix, cheque e cartao;
  - comprovantes de cartao e comprovantes Pix vinculados ao mesmo numero do relatorio.
- Registro de saidas com numero obrigatorio do relatorio e comprovante opcional.
- Historico com links claros para imagem do relatorio, cartao, Pix e saidas vinculadas.
- Compartilhamento por link curto do proprio app, no formato `https://dominio/#s/<token>`, valido por 7 dias.
- Exportacao em Excel e PDF.
- Bucket privado no Supabase Storage; links externos usam URLs assinadas temporarias.

### Arquivos importantes

```text
public/index.html                                  Aplicativo completo
public/_redirects                                  Redirect auxiliar do Netlify
netlify.toml                                       Configuracao Netlify
supabase/migrations/01_setup_inicial.sql           Tabelas, RLS e bucket
supabase/migrations/02_campo_vr.sql                Campo VR
supabase/migrations/03_fotos_cartao.sql            Comprovantes de cartao
supabase/migrations/04_fotos_pix_e_relatorio_saida.sql Pix e numero do relatorio em saidas
supabase/migrations/05_compartilhamentos_relatorio.sql Compartilhamento por token
supabase/migrations/06_permite_token_curto_compartilhamento.sql Token curto
supabase/functions/ocr-relatorio/index.ts          Edge Function que chama Gemini
```

## 2. Pre-requisitos

Contas e acessos:

- Conta no Supabase.
- Conta no Netlify.
- Conta Google AI Studio para gerar a chave do Gemini.
- Acesso ao GitHub/repo que sera usado para a nova igreja.

Ferramentas recomendadas:

- Git.
- Editor de texto ou VS Code.
- Navegador atualizado.
- Opcional: Supabase CLI, se preferir publicar Edge Function por terminal.

Nunca copie para outra igreja:

- URL/chave publishable de um projeto Supabase existente.
- Chave secreta do Gemini.
- Usuarios, senhas ou dados reais.
- Arquivos ja enviados para o bucket `fotos` de outra igreja.

## 3. Criar um novo projeto Supabase

1. Acesse o Supabase e clique em `New project`.
2. Escolha a organizacao correta, nome do projeto e regiao mais proxima.
3. Guarde a senha do banco em local seguro.
4. Aguarde o projeto ficar ativo.
5. Em `Project Settings > API`, anote:
   - `Project URL`;
   - chave publica/publishable ou anon public.

Use esses valores depois no frontend. Nao use chave `service_role` no frontend, no GitHub ou no Netlify.

## 4. Executar migrations SQL

No Supabase, abra `SQL Editor` e execute os arquivos de `supabase/migrations/` na ordem numerica.

Ordem correta:

1. `01_setup_inicial.sql`
2. `02_campo_vr.sql`
3. `03_fotos_cartao.sql`
4. `04_fotos_pix_e_relatorio_saida.sql`
5. `05_compartilhamentos_relatorio.sql`
6. `06_permite_token_curto_compartilhamento.sql`

Observacoes importantes:

- A migration `01` cria as tabelas `profiles`, `entradas`, `saidas`, o bucket privado `fotos` e as politicas iniciais.
- A migration `04` e obrigatoria para comprovantes Pix e para o campo `num_relatorio` em saidas.
- A migration `05` cria a tabela/funcoes de compartilhamento temporario.
- A migration `06` ajusta a validacao para token curto.
- Se o Supabase mostrar erro dizendo que uma tabela, coluna, bucket ou policy ja existe, confirme se a migration ja foi aplicada antes de tentar alterar manualmente.

Validacao rapida apos aplicar:

```sql
select public.ver_compartilhamento('teste-inexistente');
```

Resultado esperado para token inexistente: `null`, sem erro de funcao inexistente.

## 5. Configurar Auth e usuarios

### Criar usuarios

1. No Supabase, abra `Authentication > Users`.
2. Clique em `Add user`.
3. Informe e-mail e senha temporaria.
4. Marque `Auto Confirm User`, se disponivel.
5. Salve.

Ao criar um usuario, o trigger `handle_new_user` cria automaticamente uma linha em `profiles` com role `lancador`.

### Tornar um usuario administrador

Depois de criar o usuario, execute no SQL Editor:

```sql
update public.profiles
set role = 'admin', nome = 'Nome do Administrador'
where id = (
  select id from auth.users where email = 'email-do-admin@exemplo.com'
);
```

Para manter alguem apenas como lancador:

```sql
update public.profiles
set role = 'lancador', nome = 'Nome do Lancador'
where id = (
  select id from auth.users where email = 'email-do-lancador@exemplo.com'
);
```

## 6. Storage: bucket e politicas

A migration `01_setup_inicial.sql` cria o bucket privado `fotos`:

```sql
insert into storage.buckets (id, name, public) values ('fotos', 'fotos', false);
```

Politicas criadas:

- Usuarios autenticados podem enviar arquivos para o bucket `fotos`.
- Apenas administradores podem listar/visualizar objetos diretamente.
- Compartilhamento externo usa URL assinada temporaria, nao bucket publico.

Pastas usadas pelo app dentro do bucket:

```text
entradas/<numero-relatorio>/...
cartao/<numero-relatorio>/...
pix/<numero-relatorio>/...
saidas/<numero-relatorio>/...
```

Nao torne o bucket `fotos` publico. Se fizer isso, qualquer pessoa com caminho do arquivo podera acessar imagens sem prazo de expiracao.

## 7. Edge Function de OCR e Gemini

A funcao esta em:

```text
supabase/functions/ocr-relatorio/index.ts
```

Ela recebe a imagem do relatorio e chama o modelo `gemini-2.5-flash`. A chave Gemini deve ficar somente como secret no Supabase.

### Criar chave Gemini

1. Acesse Google AI Studio.
2. Crie uma API key para o projeto da igreja.
3. Guarde a chave em local seguro.
4. Nao cole a chave no `public/index.html`, README, GitHub ou Netlify.

### Configurar secret no Supabase

No Dashboard:

1. Abra `Edge Functions > Secrets`.
2. Crie a secret `GEMINI_API_KEY`.
3. Cole a chave Gemini.
4. Salve.

Com Supabase CLI, alternativa:

```bash
supabase login
supabase link --project-ref <project-ref-do-supabase>
supabase secrets set GEMINI_API_KEY="<chave-gemini>"
```

### Publicar a funcao

Pelo Dashboard, crie/publice uma Edge Function com o nome exato:

```text
ocr-relatorio
```

Use o conteudo de `supabase/functions/ocr-relatorio/index.ts`.

Com Supabase CLI, alternativa:

```bash
supabase functions deploy ocr-relatorio
```

Nao use `--no-verify-jwt` a menos que voce tenha decidido tornar a funcao publica. O app chama a funcao com usuario logado.

## 8. Configurar o frontend para uma nova igreja

Abra `public/index.html` e localize o bloco:

```js
const SUPABASE_URL = '...';
const SUPABASE_KEY = '...';
```

Substitua pelos valores do novo projeto Supabase:

```js
const SUPABASE_URL = '<PROJECT_URL_DO_SUPABASE>';
const SUPABASE_KEY = '<CHAVE_PUBLICA_PUBLISHABLE_OU_ANON>';
```

Pode versionar a chave publica/publishable do Supabase. Ela foi feita para uso no navegador. O que nunca pode ser versionado e a chave `service_role`, segredos do banco, senha do banco ou `GEMINI_API_KEY`.

### Personalizacao basica

Itens comuns para personalizar:

- Nome visivel do sistema: procurar por `Tesouraria da Igreja` e `Tesouraria` em `public/index.html`.
- Nome/unidade padrao: nao ha unidade fixa; o campo e preenchido pelo OCR ou manualmente.
- Usuario administrador: configurar em `profiles`, conforme a secao de Auth.
- Categorias de saida: procurar pelo `<select id="sCat">` em `public/index.html` e ajustar as `<option>`.
- Dominio publico: configurar no Netlify, conforme a secao de deploy.

## 9. Deploy no Netlify

### Opção recomendada: GitHub conectado

1. Publique o repositorio no GitHub da nova igreja ou responsavel.
2. No Netlify, clique em `Add new site > Import an existing project`.
3. Conecte o repositorio.
4. Build settings:
   - Build command: vazio.
   - Publish directory: `public`.
5. Confirme que `netlify.toml` esta no repositorio.
6. Clique em deploy.

O `netlify.toml` atual usa:

```toml
[build]
  publish = "public"
  command = ""
```

### Deploy manual por upload

Se fizer upload manual, envie o conteudo completo da pasta `public`, incluindo:

```text
index.html
_redirects
```

O arquivo `_redirects` e auxiliar. O compartilhamento atual usa `/#s/<token>` e nao depende de redirect, mas manter o arquivo ajuda caso links antigos `/s/<token>` sejam usados.

## 10. Dominio opcional

No Netlify:

1. Abra o site.
2. Va em `Domain management`.
3. Adicione o dominio ou subdominio desejado.
4. Configure DNS conforme instrucoes do Netlify.
5. Aguarde o HTTPS ficar ativo.

Depois, gere um novo link de compartilhamento para conferir que ele usa o dominio correto.

## 11. Teste de ponta a ponta

Execute este roteiro antes de entregar para a igreja:

1. Criar um usuario admin.
2. Login como admin.
3. Criar um usuario lancador.
4. Login como lancador e confirmar que ele nao ve Historico, Pessoas nem Dashboard.
5. Como lancador ou admin, registrar uma entrada:
   - tirar/enviar foto do relatorio;
   - usar `Ler campos com IA (Gemini)`;
   - revisar manualmente numero, data, hora, valores e culto/periodo;
   - anexar comprovante de cartao;
   - anexar comprovante Pix;
   - salvar.
6. Registrar uma saida com `Numero do relatorio` preenchido e comprovante opcional.
7. Login como admin e abrir Historico.
8. Conferir se aparecem links separados para:
   - imagem do relatorio de receitas;
   - comprovante de cartao;
   - comprovante Pix;
   - comprovante de saida vinculada.
9. Clicar em `Compartilhar` e enviar para WhatsApp/e-mail.
10. Abrir o link compartilhado em janela anonima ou outro celular.
11. Confirmar que a tela publica mostra os botoes dos arquivos.
12. Gerar Excel e PDF.

## 12. Backup e rotina operacional

Recomendado:

- Exportar periodicamente tabelas importantes do Supabase:
  - `profiles`
  - `entradas`
  - `saidas`
  - `compartilhamentos` (opcional; sao temporarios)
- Monitorar o uso do Storage no Supabase.
- Baixar copia das imagens do bucket `fotos` em rotina mensal, enquanto os arquivos ainda estiverem no Supabase.
- Guardar backups fora da conta pessoal de um unico usuario.
- Documentar quem e admin e quem pode criar usuarios.

Para projetos maiores, use backup automatico do banco e uma rotina separada para arquivos do Storage.

## 13. Checklist de seguranca

Antes de entregar:

- [ ] `GEMINI_API_KEY` configurada apenas em Edge Function Secrets.
- [ ] Nenhuma chave `service_role` no GitHub, Netlify ou frontend.
- [ ] Bucket `fotos` privado.
- [ ] RLS ativado nas tabelas `profiles`, `entradas`, `saidas` e `compartilhamentos`.
- [ ] Pelo menos um administrador configurado.
- [ ] Usuarios lancadores testados sem acesso ao Historico.
- [ ] Senhas temporarias trocadas ou comunicadas com seguranca.
- [ ] Deploy aponta para o projeto Supabase correto da igreja.
- [ ] Links compartilhados testados em navegador anonimo.
- [ ] Dominio/HTTPS funcionando, se aplicavel.

## 14. Atualizacao futura do sistema

Quando houver nova versao:

1. Fazer backup dos dados antes de atualizar banco ou app.
2. Ler novas migrations em `supabase/migrations/`.
3. Executar apenas as migrations novas, na ordem numerica.
4. Atualizar `public/index.html` e demais arquivos no GitHub.
5. Fazer novo deploy no Netlify.
6. Testar login, entrada, saida, historico, compartilhamento, Excel e PDF.

Nunca rode `drop table`, `delete` ou comandos destrutivos sem backup e sem entender o impacto.

## 15. Solucao de problemas

### Botao Compartilhar mostra erro

Possiveis causas:

- Migrations `05` e `06` nao foram aplicadas.
- Schema do Supabase ainda nao recarregou.
- Usuario logado nao e admin.
- Algum arquivo do relatorio nao conseguiu gerar URL assinada.

Teste no SQL Editor:

```sql
select public.ver_compartilhamento('teste-inexistente');
```

Se der erro de funcao inexistente, rode as migrations `05` e `06` novamente.

### Link compartilhado abre, mas nao mostra arquivos

- O token pode estar expirado.
- O compartilhamento pode ter sido gerado antes de corrigir a configuracao.
- As URLs assinadas dos arquivos vencem em 7 dias.

Gere um novo link pelo Historico.

### Link antigo `/s/<token>` da 404

O formato atual correto e:

```text
https://dominio/#s/<token>
```

Links antigos com `/s/<token>` podem depender de redirect do Netlify. Gere um novo link.

### OCR nao funciona

Verifique:

- Edge Function publicada com nome `ocr-relatorio`.
- Secret `GEMINI_API_KEY` configurada.
- Usuario esta logado.
- A foto esta legivel.
- A chave Gemini tem permissao e saldo/cota disponivel.

### Erro ao salvar entrada ou saida

Verifique:

- Usuario esta autenticado.
- Migrations foram aplicadas na ordem.
- Campos obrigatorios foram preenchidos.
- Bucket `fotos` existe e esta com policies corretas.

### Historico nao mostra links

Verifique:

- Usuario logado e admin.
- O registro tem `foto_path`, `fotos_cartao`, `fotos_pix` ou saida com `num_relatorio` igual ao numero da entrada.
- Migrations `03` e `04` foram aplicadas.

### Netlify mostra versao antiga

- Confirme que o deploy usou o commit mais recente.
- Force reload no celular.
- Se usou upload manual, confirme que enviou a pasta `public` atualizada.

## 16. Futura migracao de comprovantes para VPS

Objetivo futuro: reduzir uso do Supabase Storage gratuito.

Arquitetura recomendada:

- Supabase continua responsavel por:
  - banco Postgres;
  - Auth;
  - regras de acesso;
  - metadados dos arquivos: numero do relatorio, categoria, usuario, data, caminho/URL.
- VPS passa a guardar somente arquivos:
  - imagens de relatorio;
  - comprovantes de cartao;
  - comprovantes Pix;
  - comprovantes de saidas.

Recomendacao tecnica:

- Criar uma API pequena na VPS para upload/download autenticado.
- Armazenar arquivos fora da pasta publica do site, por exemplo `/var/tesouraria/uploads`.
- Gerar links temporarios assinados na API, como o Supabase faz hoje.
- Salvar no Supabase apenas o identificador/caminho retornado pela VPS.
- Manter backup automatico da pasta de uploads.

Configuracoes necessarias para implementar depois:

- IP ou dominio da VPS.
- Sistema operacional e painel usado.
- Acesso SSH ou painel com permissao de deploy.
- Local de armazenamento desejado.
- Politica de backup.
- Limite de tamanho por arquivo.
- Se havera CDN ou apenas acesso direto via API.
- Certificado HTTPS ativo.

Nao implemente essa migracao sem antes criar plano de rollback e rotina de backup. O Supabase deve continuar como fonte de verdade para dados e permissoes.

## 17. Checklist final de entrega

- [ ] Projeto Supabase criado para a nova igreja.
- [ ] Migrations `01` a `06` executadas.
- [ ] Auth configurado e usuarios criados.
- [ ] Admin definido em `profiles`.
- [ ] Bucket `fotos` privado confirmado.
- [ ] Secret `GEMINI_API_KEY` configurada.
- [ ] Edge Function `ocr-relatorio` publicada.
- [ ] `SUPABASE_URL` e `SUPABASE_KEY` do frontend apontam para o novo projeto.
- [ ] Categorias e textos personalizados, se necessario.
- [ ] Site publicado no Netlify.
- [ ] Dominio configurado, se houver.
- [ ] Entrada testada com foto, OCR, cartao e Pix.
- [ ] Saida testada com numero do relatorio.
- [ ] Historico e compartilhamento testados.
- [ ] Excel e PDF testados.
- [ ] Backup e responsaveis documentados.