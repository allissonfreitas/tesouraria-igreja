-- Adiciona o campo de comprovantes de cartão (várias fotos por relatório).
-- As fotos ficam vinculadas ao registro da entrada (mesmo Nº de relatório e data).
-- Cole no SQL Editor do Supabase e clique Run.
alter table public.entradas add column if not exists fotos_cartao jsonb not null default '[]';
