import { Link } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { Cloud, Menu, X } from "lucide-react";

import { useSession } from "@/hooks/use-session";
import { cn } from "@/lib/utils";

const NAV = [
  { to: "/", label: "خانه" },
  { to: "/pricing", label: "قیمت‌ها" },
  { to: "/blog", label: "بلاگ" },
  { to: "/docs", label: "مستندات" },
  { to: "/about", label: "درباره ما" },
] as const;

export function SiteHeader() {
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);
  const { session } = useSession();

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header
      className={cn(
        "fixed inset-x-0 top-0 z-50 h-14 border-b transition-colors duration-200",
        scrolled ? "border-hairline bg-background/85 backdrop-blur-xl" : "border-transparent",
      )}
    >
      <div className="mx-auto flex h-full max-w-6xl items-center justify-between px-5">
        <Link to="/" className="flex items-center gap-2 text-sm font-semibold">
          <Cloud className="size-5 text-brand" strokeWidth={1.75} />
          <span>
            دیاراد<span className="text-brand">کلود</span>
          </span>
        </Link>

        <nav className="hidden items-center gap-1 md:flex">
          {NAV.map((item) => (
            <Link
              key={item.to}
              to={item.to}
              activeOptions={{ exact: item.to === "/" }}
              activeProps={{ className: "text-foreground bg-secondary/70" }}
              className="rounded-md px-3 py-1.5 text-[13px] text-muted-foreground transition-colors hover:bg-secondary/50 hover:text-foreground"
            >
              {item.label}
            </Link>
          ))}
        </nav>

        <div className="flex items-center gap-2">
          {session ? (
            <Link
              to="/panel"
              className="hidden h-9 items-center rounded-md bg-primary px-4 text-[13px] font-medium text-primary-foreground transition-opacity hover:opacity-85 md:inline-flex"
            >
              پنل کاربری
            </Link>
          ) : (
            <>
              <Link
                to="/auth"
                search={{ mode: "login" }}
                className="hidden h-9 items-center rounded-md border border-hairline px-4 text-[13px] text-foreground transition-colors hover:border-foreground/25 md:inline-flex"
              >
                ورود
              </Link>
              <Link
                to="/auth"
                search={{ mode: "register" }}
                className="hidden h-9 items-center rounded-md bg-brand px-4 text-[13px] font-medium text-brand-foreground transition-opacity hover:opacity-90 md:inline-flex"
              >
                ثبت‌نام
              </Link>
            </>
          )}
          <button
            type="button"
            aria-label="منو"
            onClick={() => setOpen((v) => !v)}
            className="inline-flex size-9 items-center justify-center rounded-md border border-hairline md:hidden"
          >
            {open ? <X className="size-4" /> : <Menu className="size-4" />}
          </button>
        </div>
      </div>

      {open && (
        <div className="border-b border-hairline bg-background px-5 pb-4 md:hidden">
          <div className="flex flex-col gap-1 pt-2">
            {NAV.map((item) => (
              <Link
                key={item.to}
                to={item.to}
                onClick={() => setOpen(false)}
                className="rounded-md px-3 py-2 text-sm text-muted-foreground hover:bg-secondary/60 hover:text-foreground"
              >
                {item.label}
              </Link>
            ))}
            <Link
              to={session ? "/panel" : "/auth"}
              onClick={() => setOpen(false)}
              className="mt-2 rounded-md bg-brand px-3 py-2 text-center text-sm font-medium text-brand-foreground"
            >
              {session ? "پنل کاربری" : "ورود / ثبت‌نام"}
            </Link>
          </div>
        </div>
      )}
    </header>
  );
}
