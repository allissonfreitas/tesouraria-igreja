-- Adiciona comprovantes Pix nas entradas e vinculo de saidas ao numero do relatorio.
-- Campos opcionais no banco para preservar registros existentes; o frontend valida novos lancamentos.

alter table public.entradas
  add column if not exists fotos_pix jsonb not null default '[]';

alter table public.saidas
  add column if not exists num_relatorio text;

create index if not exists saidas_num_relatorio_idx
  on public.saidas (num_relatorio);
