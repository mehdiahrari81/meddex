"use client";

import Link from "next/link";
import { usePathname, useSearchParams } from "next/navigation";
import { useState } from "react";
import type { NavGroup } from "@/lib/nav";
import { BrandMark, Icon, navigationIcon } from "./icon";

export function Sidebar({ groups }: { groups: NavGroup[] }) {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  const query = useSearchParams().toString();
  const current = pathname + (query ? `?${query}` : "");
  const specificPage = groups
    .flatMap((group) => group.items)
    .some((item) => item.href.includes("?") && item.href === current);
  return (
    <aside className="sidebar" aria-label="Administration navigation">
      <div className="sidebar-heading">
        <Link
          href={groups[0]?.items[0]?.href ?? "/"}
          className="brand"
          aria-label="MediExplain workspace"
        >
          <BrandMark />
          <div>
            MediExplain<span>Governance workspace</span>
          </div>
        </Link>
        <button
          className="menu-toggle"
          aria-expanded={open}
          aria-controls="admin-navigation"
          onClick={() => setOpen(!open)}
        >
          <Icon name={open ? "close" : "menu"} />
          <span>{open ? "Close menu" : "Open menu"}</span>
        </button>
      </div>
      <div
        id="admin-navigation"
        className={`nav-container ${open ? "is-open" : ""}`}
      >
        {groups.map((group) => (
          <nav key={group.title} aria-label={group.title}>
            <div className="nav-group">{group.title}</div>
            {group.items.map((item) => (
              <Link
                className="nav-link"
                key={item.href + item.label}
                href={item.href}
                aria-current={
                  current === item.href ||
                  (!specificPage && item.href === pathname) ||
                  (!item.href.includes("?") &&
                    item.href !== "/" &&
                    pathname.startsWith(item.href + "/"))
                    ? "page"
                    : undefined
                }
                onClick={() => setOpen(false)}
              >
                <Icon name={navigationIcon(item.href)} size={18} />
                <span>{item.label}</span>
              </Link>
            ))}
          </nav>
        ))}
      </div>
      <div className="sidebar-footer">
        <span className="sidebar-footer-icon">
          <Icon name="shield" />
        </span>
        <div>
          <strong>Accountable by design</strong>
          <span>Permission checked · Audit logged</span>
        </div>
      </div>
    </aside>
  );
}
