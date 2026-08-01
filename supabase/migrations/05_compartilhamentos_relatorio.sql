-- Cria compartilhamentos temporarios por token para enviar um unico link curto.
-- Os arquivos continuam privados no Storage; o payload guarda URLs assinadas com validade limitada.

create table if not exists public.compartilhamentos (
  token text primary key,
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null,
  criado_por uuid references auth.users(id),
  payload jsonb not null
);

alter table public.compartilhamentos enable row level security;

create index if not exists compartilhamentos_expira_em_idx
  on public.compartilhamentos (expira_em);

create or replace function public.salvar_compartilhamento(
  p_token text,
  p_payload jsonb,
  p_expira_em timestamptz
)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Apenas administradores podem criar compartilhamentos';
  end if;

  if p_token is null or length(trim(p_token)) < 24 then
    raise exception 'Token de compartilhamento invalido';
  end if;

  if p_expira_em is null or p_expira_em <= now() or p_expira_em > now() + interval '8 days' then
    raise exception 'Validade de compartilhamento invalida';
  end if;

  insert into public.compartilhamentos (token, payload, expira_em, criado_por)
  values (p_token, p_payload, p_expira_em, auth.uid())
  on conflict (token) do update set
    payload = excluded.payload,
    expira_em = excluded.expira_em,
    criado_por = excluded.criado_por,
    criado_em = now();

  return p_token;
end;
$$;

create or replace function public.ver_compartilhamento(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payload jsonb;
begin
  select payload into v_payload
  from public.compartilhamentos
  where token = p_token
    and expira_em > now();

  return v_payload;
end;
$$;

grant execute on function public.salvar_compartilhamento(text, jsonb, timestamptz) to authenticated;
grant execute on function public.ver_compartilhamento(text) to anon, authenticated;