-- Ajusta a validacao para tokens de compartilhamento mais curtos na URL /s/<token>.

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

  if p_token is null or length(trim(p_token)) < 16 then
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

notify pgrst, 'reload schema';