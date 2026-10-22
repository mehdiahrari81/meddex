"use client";

import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { useEffect, useRef, useState, type ReactNode } from "react";
import type { NavGroup } from "@/lib/nav";
import { Icon, navigationIcon } from "./icon";

export function WorkspaceHeader({
  groups,
  email,
  role,
  children,
}: {
  groups: NavGroup[];
  email: string;
  role: string;
  children: ReactNode;
}) {
  const pathname = usePathname();
  const params = useSearchParams().toString();
  const router = useRouter();
  const [query, setQuery] = useState("");
  const search = useRef<HTMLInputElement>(null);
  const pages = groups.flatMap((group) => group.items);
  const location = pathname + (params ? `?${params}` : "");
  const current =
    (
      pages.find((item) => item.href === location) ??
      pages.find((item) => item.href === pathname)
    )?.label ?? "Content details";
  const matches = query.trim()
    ? pages
        .filter((item) =>
          item.label.toLowerCase().includes(query.trim().toLowerCase()),
        )
        .slice(0, 6)
    : [];
  useEffect(() => {
    const focus = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key === "k") {
        event.preventDefault();
        search.current?.focus();
      }
      if (event.key === "Escape") {
        setQuery("");
        search.current?.blur();
      }
    };
    document.addEventListener("keydown", focus);
    return () => document.removeEventListener("keydown", focus);
  }, []);
  return (
    <header className="topbar">
      <div className="breadcrumb">
        <span>Workspace</span>
        <Icon name="chevron" size={13} />
        <strong>{current}</strong>
      </div>
      <div className="workspace-search">
        <Icon name="search" size={17} />
        <input
          ref={search}
          type="search"
          aria-label="Find an administration page"
          placeholder="Find a page…"
          value={query}
          autoComplete="off"
          onChange={(event) => setQuery(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter" && matches[0]) {
              router.push(matches[0].href);
              setQuery("");
            }
          }}
        />
        <kbd>⌘ K</kbd>
        {query.trim() && (
          <div className="search-results" aria-label="Matching pages">
            {matches.length ? (
              matches.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={() => setQuery("")}
                >
                  <Icon name={navigationIcon(item.href)} size={17} />
                  {item.label}
                  <Icon name="arrow" size={15} />
                </Link>
              ))
            ) : (
              <p>No pages match “{query}”.</p>
            )}
          </div>
        )}
      </div>
      <div className="account-summary">
        <span className="avatar">
          {email
            .split("@")[0]
            .split(/[._-]/)
            .map((part) => part[0])
            .slice(0, 2)
            .join("")
            .toUpperCase()}
        </span>
        <div>
          <strong>{role.toLowerCase().replaceAll("_", " ")}</strong>
          <span>{email}</span>
        </div>
      </div>
      {children}
    </header>
  );
}
