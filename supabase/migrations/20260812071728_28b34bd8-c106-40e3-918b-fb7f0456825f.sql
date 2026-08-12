CREATE OR REPLACE FUNCTION public.staff_verify(_username text, _password text)
RETURNS TABLE (id uuid, email text, role public.app_role, user_id uuid, display_name text)
LANGUAGE sql SECURITY DEFINER SET search_path = public, extensions AS $$
  SELECT s.id, s.email, s.role, s.user_id, s.display_name
  FROM public.staff_accounts s
  WHERE lower(s.username) = lower(_username)
    AND s.is_active
    AND s.bootstrap_password_hash IS NOT NULL
    AND s.bootstrap_password_hash = crypt(_password, s.bootstrap_password_hash);
$$;
REVOKE EXECUTE ON FUNCTION public.staff_verify(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.staff_verify(text, text) TO service_role;
