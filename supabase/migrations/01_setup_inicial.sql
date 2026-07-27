-- ============================================================
-- TESOURARIA DA IGREJA — Setup do banco (Supabase)
-- Cole este script inteiro no SQL Editor do Supabase e clique RUN
-- ============================================================

-- 1) PERFIS (nome e função de cada pessoa)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text not null default '',
  role text not null default 'lancador' check (role in ('admin','lancador'))
);
alter table public.profiles enable row level security;

-- Função que verifica se quem está logado é administrador
create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create policy "ver_perfil" on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_admin());

create policy "admin_edita_perfil" on public.profiles
  for update to authenticated
  using (public.is_admin());

-- Cria o perfil automaticamente quando um usuário é criado
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, nome)
  values (new.id, coalesce(new.raw_user_meta_data->>'nome', split_part(new.email,'@',1)));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 2) ENTRADAS (relatórios de receitas)
create table public.entradas (
  id bigint generated always as identity primary key,
  criado_em timestamptz not null default now(),
  user_id uuid not null default auth.uid() references auth.users(id),
  num text, unidade text,
  data date not null, hora text,
  notas jsonb not null default '{}',
  moedas numeric not null default 0,
  dinheiro numeric not null default 0,
  pix numeric not null default 0,
  cheque numeric not null default 0,
  cartao numeric not null default 0,
  geral numeric not null default 0,
  pessoas int, lacre text, resp text,
  foto_path text, por text
);
alter table public.entradas enable row level security;

-- Qualquer pessoa logada pode LANÇAR
create policy "entradas_insert" on public.entradas
  for insert to authenticated
  with check (auth.uid() = user_id);

-- Só ADMIN pode VER e EXCLUIR
create policy "entradas_select_admin" on public.entradas
  for select to authenticated using (public.is_admin());

create policy "entradas_delete_admin" on public.entradas
  for delete to authenticated using (public.is_admin());

-- 3) SAÍDAS (despesas)
create table public.saidas (
  id bigint generated always as identity primary key,
  criado_em timestamptz not null default now(),
  user_id uuid not null default auth.uid() references auth.users(id),
  data date not null,
  descricao text not null,
  categoria text,
  valor numeric not null,
  foto_path text, por text
);
alter table public.saidas enable row level security;

create policy "saidas_insert" on public.saidas
  for insert to authenticated
  with check (auth.uid() = user_id);

create policy "saidas_select_admin" on public.saidas
  for select to authenticated using (public.is_admin());

create policy "saidas_delete_admin" on public.saidas
  for delete to authenticated using (public.is_admin());

-- 4) FOTOS (armazenamento das imagens dos relatórios)
insert into storage.buckets (id, name, public) values ('fotos', 'fotos', false);

create policy "fotos_upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'fotos');

create policy "fotos_ver_admin" on storage.objects
  for select to authenticated
  using (bucket_id = 'fotos' and public.is_admin());

-- ============================================================
-- DEPOIS DE CRIAR OS USUÁRIOS (Authentication > Users > Add user),
-- rode a linha abaixo trocando o e-mail, para tornar alguém ADMIN:
--
-- update public.profiles set role = 'admin', nome = 'Pastor'
--   where id = (select id from auth.users where email = 'email-do-pastor@gmail.com');
-- ============================================================
