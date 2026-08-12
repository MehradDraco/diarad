CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE public.app_role AS ENUM ('admin','support','user');
CREATE TYPE public.ticket_category AS ENUM ('password_reset','technical','payment','abuse','intl_internet');
CREATE TYPE public.ticket_status AS ENUM ('open','answered','pending_user','closed');
CREATE TYPE public.ticket_priority AS ENUM ('low','normal','high','critical');
CREATE TYPE public.order_status AS ENUM ('pending','approved','rejected','canceled');
CREATE TYPE public.service_status AS ENUM ('pending','active','suspended','expired');
CREATE TYPE public.request_status AS ENUM ('pending','approved','rejected','done');

CREATE OR REPLACE FUNCTION public.update_updated_at_column() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$ LANGUAGE plpgsql SET search_path = public;

-- ROLES
CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL DEFAULT 'user',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role);
$$;

CREATE OR REPLACE FUNCTION public.is_staff(_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role IN ('admin','support'));
$$;

CREATE POLICY "own roles readable" ON public.user_roles FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_staff(auth.uid()));
CREATE POLICY "admins manage roles" ON public.user_roles FOR ALL TO authenticated USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

-- PROFILES
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  first_name text NOT NULL DEFAULT '',
  last_name text NOT NULL DEFAULT '',
  national_id text NOT NULL DEFAULT '',
  phone text NOT NULL DEFAULT '',
  birth_date date,
  city text NOT NULL DEFAULT '',
  network_name text,
  ssh_username text,
  is_blocked boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX profiles_network_name_key ON public.profiles (lower(network_name)) WHERE network_name IS NOT NULL;
CREATE UNIQUE INDEX profiles_ssh_username_key ON public.profiles (lower(ssh_username)) WHERE ssh_username IS NOT NULL;
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read own profile" ON public.profiles FOR SELECT TO authenticated USING (id = auth.uid() OR public.is_staff(auth.uid()));
CREATE POLICY "insert own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK (id = auth.uid());
CREATE POLICY "update own profile" ON public.profiles FOR UPDATE TO authenticated USING (id = auth.uid() OR public.is_staff(auth.uid())) WITH CHECK (id = auth.uid() OR public.is_staff(auth.uid()));
CREATE TRIGGER profiles_updated BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- DATACENTERS
CREATE TABLE public.datacenters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  location text NOT NULL DEFAULT '',
  host_ip text,
  is_active boolean NOT NULL DEFAULT true,
  coming_soon boolean NOT NULL DEFAULT false,
  tagline text NOT NULL DEFAULT '',
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.datacenters TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.datacenters TO authenticated;
GRANT ALL ON public.datacenters TO service_role;
ALTER TABLE public.datacenters ENABLE ROW LEVEL SECURITY;
CREATE POLICY "datacenters public read" ON public.datacenters FOR SELECT USING (true);
CREATE POLICY "datacenters admin write" ON public.datacenters FOR ALL TO authenticated USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));
CREATE TRIGGER datacenters_updated BEFORE UPDATE ON public.datacenters FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- PLANS
CREATE TABLE public.plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  datacenter_id uuid REFERENCES public.datacenters(id) ON DELETE CASCADE,
  kind text NOT NULL DEFAULT 'vps',
  name text NOT NULL,
  ram text NOT NULL DEFAULT '',
  cpu text NOT NULL DEFAULT '',
  disk text NOT NULL DEFAULT '',
  bandwidth_gb int NOT NULL DEFAULT 100,
  price_toman bigint NOT NULL DEFAULT 0,
  is_popular boolean NOT NULL DEFAULT false,
  is_locked boolean NOT NULL DEFAULT false,
  lock_note text NOT NULL DEFAULT 'فعلاً فروش نمی‌رود',
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.plans TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.plans TO authenticated;
GRANT ALL ON public.plans TO service_role;
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "plans public read" ON public.plans FOR SELECT USING (true);
CREATE POLICY "plans admin write" ON public.plans FOR ALL TO authenticated USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));
CREATE TRIGGER plans_updated BEFORE UPDATE ON public.plans FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- SERVICES
CREATE TABLE public.services (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id uuid REFERENCES public.plans(id) ON DELETE SET NULL,
  datacenter_id uuid REFERENCES public.datacenters(id) ON DELETE SET NULL,
  label text NOT NULL DEFAULT 'ابرک',
  plan_name text NOT NULL DEFAULT '',
  ip text NOT NULL DEFAULT '194.60.231.49',
  ssh_port int NOT NULL DEFAULT 9011,
  ssh_username text NOT NULL DEFAULT 'user',
  os text NOT NULL DEFAULT 'Ubuntu 22.04 LTS',
  status public.service_status NOT NULL DEFAULT 'pending',
  bandwidth_limit_gb int NOT NULL DEFAULT 100,
  bandwidth_used_gb numeric NOT NULL DEFAULT 0,
  intl_enabled boolean NOT NULL DEFAULT false,
  activated_at timestamptz,
  expires_at timestamptz,
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.services TO authenticated;
GRANT ALL ON public.services TO service_role;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
CREATE POLICY "services owner read" ON public.services FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_staff(auth.uid()));
CREATE POLICY "services staff write" ON public.services FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE TRIGGER services_updated BEFORE UPDATE ON public.services FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ORDERS
CREATE TABLE public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id uuid REFERENCES public.plans(id) ON DELETE SET NULL,
  service_id uuid REFERENCES public.services(id) ON DELETE SET NULL,
  plan_name text NOT NULL DEFAULT '',
  os text NOT NULL DEFAULT 'Ubuntu 22.04 LTS',
  months int NOT NULL DEFAULT 1,
  bonus_days int NOT NULL DEFAULT 0,
  amount_toman bigint NOT NULL DEFAULT 0,
  kind text NOT NULL DEFAULT 'new',
  status public.order_status NOT NULL DEFAULT 'pending',
  ticket_id uuid,
  reviewed_at timestamptz,
  reviewed_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.orders TO authenticated;
GRANT ALL ON public.orders TO service_role;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "orders owner read" ON public.orders FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_staff(auth.uid()));
CREATE POLICY "orders owner insert" ON public.orders FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "orders staff update" ON public.orders FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE TRIGGER orders_updated BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- TICKETS
CREATE TABLE public.tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category public.ticket_category NOT NULL DEFAULT 'technical',
  priority public.ticket_priority NOT NULL DEFAULT 'normal',
  subject text NOT NULL,
  status public.ticket_status NOT NULL DEFAULT 'open',
  service_id uuid REFERENCES public.services(id) ON DELETE SET NULL,
  assigned_to uuid,
  last_reply_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.tickets TO authenticated;
GRANT ALL ON public.tickets TO service_role;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tickets owner read" ON public.tickets FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_staff(auth.uid()));
CREATE POLICY "tickets owner insert" ON public.tickets FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "tickets update" ON public.tickets FOR UPDATE TO authenticated USING (user_id = auth.uid() OR public.is_staff(auth.uid())) WITH CHECK (user_id = auth.uid() OR public.is_staff(auth.uid()));
CREATE TRIGGER tickets_updated BEFORE UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.ticket_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid NOT NULL REFERENCES public.tickets(id) ON DELETE CASCADE,
  author_id uuid,
  author_name text NOT NULL DEFAULT '',
  is_staff boolean NOT NULL DEFAULT false,
  is_system boolean NOT NULL DEFAULT false,
  body text NOT NULL DEFAULT '',
  attachment_path text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT ON public.ticket_messages TO authenticated;
GRANT ALL ON public.ticket_messages TO service_role;
ALTER TABLE public.ticket_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ticket messages read" ON public.ticket_messages FOR SELECT TO authenticated USING (
  public.is_staff(auth.uid()) OR EXISTS (SELECT 1 FROM public.tickets t WHERE t.id = ticket_id AND t.user_id = auth.uid())
);
CREATE POLICY "ticket messages insert" ON public.ticket_messages FOR INSERT TO authenticated WITH CHECK (
  public.is_staff(auth.uid()) OR EXISTS (SELECT 1 FROM public.tickets t WHERE t.id = ticket_id AND t.user_id = auth.uid())
);

-- NOTIFICATIONS
CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text NOT NULL DEFAULT '',
  link text,
  level text NOT NULL DEFAULT 'info',
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notifications owner" ON public.notifications FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_staff(auth.uid()));
CREATE POLICY "notifications owner update" ON public.notifications FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "notifications staff insert" ON public.notifications FOR INSERT TO authenticated WITH CHECK (public.is_staff(auth.uid()) OR user_id = auth.uid());

-- BLOG
CREATE TABLE public.blog_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  title text NOT NULL,
  excerpt text NOT NULL DEFAULT '',
  body text NOT NULL DEFAULT '',
  cover_url text,
  tag text NOT NULL DEFAULT 'مقاله',
  read_minutes int NOT NULL DEFAULT 5,
  is_published boolean NOT NULL DEFAULT false,
  author_id uuid,
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.blog_posts TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.blog_posts TO authenticated;
GRANT ALL ON public.blog_posts TO service_role;
ALTER TABLE public.blog_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "published posts public" ON public.blog_posts FOR SELECT USING (is_published = true);
CREATE POLICY "staff read all posts" ON public.blog_posts FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));
CREATE POLICY "staff write posts" ON public.blog_posts FOR ALL TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));
CREATE TRIGGER blog_updated BEFORE UPDATE ON public.blog_posts FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- EXPENSES
CREATE TABLE public.expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  amount_toman bigint NOT NULL DEFAULT 0,
  category text NOT NULL DEFAULT 'general',
  note text NOT NULL DEFAULT '',
  spent_at date NOT NULL DEFAULT current_date,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.expenses TO authenticated;
GRANT ALL ON public.expenses TO service_role;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "expenses admin only" ON public.expenses FOR ALL TO authenticated USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

-- SETTINGS
CREATE TABLE public.site_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.site_settings TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.site_settings TO authenticated;
GRANT ALL ON public.site_settings TO service_role;
ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "settings public read" ON public.site_settings FOR SELECT USING (true);
CREATE POLICY "settings admin write" ON public.site_settings FOR ALL TO authenticated USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

-- SERVICE PASSWORD REQUESTS
CREATE TABLE public.service_password_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id uuid NOT NULL REFERENCES public.services(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason text NOT NULL DEFAULT '',
  status public.request_status NOT NULL DEFAULT 'pending',
  ticket_id uuid REFERENCES public.tickets(id) ON DELETE SET NULL,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.service_password_requests TO authenticated;
GRANT ALL ON public.service_password_requests TO service_role;
ALTER TABLE public.service_password_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "spr owner read" ON public.service_password_requests FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_staff(auth.uid()));
CREATE POLICY "spr owner insert" ON public.service_password_requests FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "spr staff update" ON public.service_password_requests FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));

-- INTERNATIONAL INTERNET REQUESTS
CREATE TABLE public.intl_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  service_id uuid REFERENCES public.services(id) ON DELETE SET NULL,
  months int NOT NULL DEFAULT 1,
  amount_toman bigint NOT NULL DEFAULT 0,
  purpose text NOT NULL DEFAULT '',
  accepted_terms boolean NOT NULL DEFAULT false,
  status public.request_status NOT NULL DEFAULT 'pending',
  ticket_id uuid REFERENCES public.tickets(id) ON DELETE SET NULL,
  decided_at timestamptz,
  staff_note text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.intl_requests TO authenticated;
GRANT ALL ON public.intl_requests TO service_role;
ALTER TABLE public.intl_requests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "intl owner read" ON public.intl_requests FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_staff(auth.uid()));
CREATE POLICY "intl owner insert" ON public.intl_requests FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "intl staff update" ON public.intl_requests FOR UPDATE TO authenticated USING (public.is_staff(auth.uid())) WITH CHECK (public.is_staff(auth.uid()));

-- STAFF ACCOUNTS (username -> email mapping for /diarad-admin-panel)
CREATE TABLE public.staff_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL UNIQUE,
  email text NOT NULL,
  display_name text NOT NULL DEFAULT '',
  role public.app_role NOT NULL DEFAULT 'support',
  bootstrap_password_hash text,
  user_id uuid,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.staff_accounts TO authenticated;
GRANT ALL ON public.staff_accounts TO service_role;
ALTER TABLE public.staff_accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "staff accounts staff read" ON public.staff_accounts FOR SELECT TO authenticated USING (public.is_staff(auth.uid()));

INSERT INTO public.staff_accounts (username, email, display_name, role, bootstrap_password_hash)
VALUES ('mehrad','mehrad@diarad.2bd.net','مهراد طراوتی','admin', crypt('dianaandmehrad@123', gen_salt('bf',10)));

-- SEED DATACENTERS
INSERT INTO public.datacenters (slug, name, location, host_ip, is_active, coming_soon, tagline, sort_order) VALUES
('diana-abr','دیانا ابر','ایران — تهران','194.60.231.49', true, false, 'زیرساخت داخلی با اینترنت پایدار و لِیتنسی پایین', 1),
('liasenter','لیاسنتر','خارج از کشور', NULL, false, true, 'به‌زودی — زیرساخت بین‌المللی', 2);

-- SEED PLANS
INSERT INTO public.plans (datacenter_id, kind, name, ram, cpu, disk, bandwidth_gb, price_toman, is_popular, sort_order)
SELECT d.id, 'vps', p.name, p.ram, p.cpu, p.disk, p.bw, p.price, p.pop, p.ord
FROM public.datacenters d,
(VALUES
 ('برنز','0.5GB','0.5 هسته','5GB',50,40000,false,1),
 ('نقره','1GB','0.75 هسته','10GB',100,60000,false,2),
 ('طلا','2GB','1 هسته','20GB',200,80000,false,3),
 ('الماس','4GB','1.5 هسته','30GB',300,100000,true,4),
 ('یاقوت','6GB','2 هسته','40GB',400,140000,false,5),
 ('کهکشان','8GB','2.5 هسته','50GB',500,180000,false,6)
) AS p(name,ram,cpu,disk,bw,price,pop,ord)
WHERE d.slug = 'diana-abr';

INSERT INTO public.plans (datacenter_id, kind, name, ram, cpu, disk, bandwidth_gb, price_toman, sort_order)
SELECT d.id, 'addon', p.name, '', '', '', 0, p.price, p.ord
FROM public.datacenters d,
(VALUES ('+1GB رم',30000,1),('+10GB SSD',20000,2),('+0.5 هسته CPU',40000,3),('فعال‌سازی GPU',150000,4)) AS p(name,price,ord)
WHERE d.slug = 'diana-abr';

INSERT INTO public.plans (datacenter_id, kind, name, ram, cpu, disk, bandwidth_gb, price_toman, sort_order)
SELECT d.id, 'intl', 'اینترنت بین‌الملل ماهانه', '', '', '', 0, 50000, 1
FROM public.datacenters d WHERE d.slug = 'diana-abr';

INSERT INTO public.site_settings (key, value) VALUES
('payment', '{"card_number":"6037697677881945","card_holder":"مهراد طراوتی","bank":"صادرات"}'::jsonb),
('brand', '{"name":"دیاراد کلود","domain":"diarad.2bd.net","host_ip":"194.60.231.49","service_days":31}'::jsonb),
('home', '{"hero_image_url":"","announcement":""}'::jsonb),
('sales', '{"vps_enabled":true,"intl_enabled":true}'::jsonb);
