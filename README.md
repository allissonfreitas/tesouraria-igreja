# Tesouraria da Igreja

Aplicativo web para registro de **dízimos e ofertas** por culto, com foto do Relatório de Receitas, leitura automática por IA, controle de acesso e relatórios em Excel e PDF.

## Como funciona

1. A pessoa autorizada tira a foto do Relatório de Receitas pelo celular
2. A IA (Gemini) lê os campos preenchidos à caneta e preenche o formulário
3. Confere-se os valores com o papel e salva
4. A foto e os dados ficam armazenados, visíveis **somente ao administrador**

## Perfis de acesso

| Perfil | O que pode fazer |
|---|---|
| **Administrador** | Vê tudo: dashboard, histórico, valores, fotos, relatórios e gerencia funções. Pode anexar fotos da galeria/WhatsApp |
| **Só registra** | Apenas lança receitas e saídas. Não vê valores, totais nem histórico. Só pode usar a câmera |

## Funcionalidades

- Formulário idêntico ao Relatório de Receitas oficial (VR, notas de R$ 2 a R$ 200, moedas, depósitos PIX, cheque, cartão)
- Cálculo automático dos totais, com campos formatados em R$
- Leitura da foto por IA (Gemini) via Edge Function
- Comprovantes de cartão (várias fotos) vinculados ao número do relatório
- Registro de saídas com categoria e comprovante
- Dashboard com filtro por mês, cards por forma de pagamento e gráficos
- Exportação em **Excel** (3 abas, com links das fotos) e **PDF** formatado
- Modo claro/escuro

## Estrutura

```
public/                     site publicado (Netlify)
  index.html                aplicativo completo (arquivo único)
supabase/
  functions/ocr-relatorio/  Edge Function que chama o Gemini
  migrations/               scripts SQL do banco, na ordem de execução
netlify.toml                configuração de publicação
```

## Tecnologias

- **Front-end:** HTML + CSS + JavaScript puro (sem build), Chart.js, SheetJS, jsPDF
- **Back-end:** Supabase (Auth, Postgres com RLS, Storage, Edge Functions)
- **IA:** Google Gemini (`gemini-2.5-flash`)
- **Hospedagem:** Netlify

## Configuração do zero

### 1. Banco de dados (Supabase)

No **SQL Editor**, rode os arquivos de `supabase/migrations/` na ordem numérica.

Para tornar alguém administrador:

```sql
update public.profiles set role = 'admin', nome = 'Nome da Pessoa'
where id = (select id from auth.users where email = 'email@exemplo.com');
```

### 2. Usuários

**Authentication → Users → Add user** (marcar *Auto Confirm User*). Novos usuários entram como `lancador` (só registra).

### 3. Leitura por IA

1. Gere uma chave em [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. Em **Edge Functions → Secrets**, crie a secret `GEMINI_API_KEY`
3. Publique a função com o nome exato `ocr-relatorio` usando o código de `supabase/functions/ocr-relatorio/index.ts`

### 4. Site

Conecte este repositório ao Netlify. A publicação usa a pasta `public/` (já definida em `netlify.toml`).

Se as chaves do Supabase mudarem, atualize as constantes `SUPABASE_URL` e `SUPABASE_KEY` no início do `<script>` em `public/index.html`.

## Segurança

- As regras de acesso são aplicadas no banco (RLS), não apenas na tela — quem não é administrador não consegue ler valores nem fotos, mesmo tentando burlar pelo navegador
- A chave do Gemini fica no servidor (Edge Function), nunca exposta no site
- Cada registro guarda quem lançou e quando
- A chave publicável do Supabase no `index.html` é pública por natureza e segura de versionar. **A chave secreta (`sb_secret_...`) nunca deve ser colocada neste repositório**
