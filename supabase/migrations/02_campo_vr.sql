-- Adiciona o campo "Total de VR (recibos pagos na localidade)" nas entradas.
-- Cole no SQL Editor do Supabase e clique Run.
alter table public.entradas add column if not exists vr numeric not null default 0;
