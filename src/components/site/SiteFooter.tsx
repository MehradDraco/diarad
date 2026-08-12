import { Link } from "@tanstack/react-router";

import { BRAND } from "@/lib/diarad";

export function SiteFooter() {
  return (
    <footer className="mt-24 border-t border-hairline">
      <div className="mx-auto grid max-w-6xl gap-8 px-5 py-12 sm:grid-cols-2 md:grid-cols-4">
        <div>
          <div className="text-sm font-semibold">دیاراد کلود</div>
          <p className="mt-2 text-[13px] leading-7 text-muted-foreground">
            زیرساخت ابری ساده و سریع. دیتاسنتر دیانا ابر در ایران و لیاسنتر به‌زودی خارج از کشور.
          </p>
          <p className="ltr-mono mt-3 text-[11px] text-muted-foreground">{BRAND.domain}</p>
        </div>
        <FooterCol
          title="محصولات"
          links={[
            { to: "/pricing", label: "پلن‌های ابرک" },
            { to: "/pricing", label: "افزونه‌های ارتقا" },
            { to: "/docs", label: "مستندات" },
          ]}
        />
        <FooterCol
          title="شرکت"
          links={[
            { to: "/about", label: "درباره ما" },
            { to: "/blog", label: "بلاگ" },
            { to: "/status", label: "وضعیت سرویس" },
          ]}
        />
        <FooterCol
          title="حساب کاربری"
          links={[
            { to: "/auth", label: "ورود و ثبت‌نام" },
            { to: "/forgot-password", label: "فراموشی رمز عبور" },
            { to: "/panel", label: "پنل کاربری" },
          ]}
        />
      </div>
      <div className="border-t border-hairline">
        <div className="mx-auto flex max-w-6xl flex-col gap-2 px-5 py-5 text-[12px] text-muted-foreground sm:flex-row sm:items-center sm:justify-between">
          <span>© دیاراد کلود — تمامی حقوق محفوظ است.</span>
          <span className="ltr-mono">diana abr · liasenter (soon)</span>
        </div>
      </div>
    </footer>
  );
}

function FooterCol({
  title,
  links,
}: {
  title: string;
  links: { to: string; label: string }[];
}) {
  return (
    <div>
      <div className="text-[12px] font-medium text-muted-foreground">{title}</div>
      <div className="mt-3 flex flex-col gap-2">
        {links.map((l) => (
          <Link
            key={l.label + l.to}
            to={l.to}
            className="text-[13px] text-foreground/80 transition-colors hover:text-brand"
          >
            {l.label}
          </Link>
        ))}
      </div>
    </div>
  );
}
