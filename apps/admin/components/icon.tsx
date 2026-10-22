import type { CSSProperties } from "react";

const paths = {
  dashboard: "M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z",
  activity: "M3 12h4l3-8 4 16 3-8h4",
  book: "M12 6c-3-3-7-3-10-2v15c3-1 7-1 10 2 3-3 7-3 10-2V4c-3-1-7-1-10 2z M12 6v15",
  layers: "m12 3 10 6-10 6L2 9z M2 13l10 6 10-6 M2 17l10 6 10-6",
  language:
    "M3 5h12 M9 3v2 M5 5c0 6 7 10 7 10 M13 5c0 5-4 9-9 11 M14 21l4-11 4 11 M16 17h4",
  check: "m5 12 4 4L19 6",
  shield: "m12 3 9 4v5c0 5-5 8-9 10-4-2-9-5-9-10V7z m-4 9 3 3 5-6",
  report: "M14 3H5v18h14V8z M14 3v5h5 M8 12h8 M8 16h5",
  inbox: "M4 4h16l2 12v4H2v-4z M2 16h6l2 3h4l2-3h6",
  upload: "M12 16V3 m-5 5 5-5 5 5 M4 15v6h16v-6",
  globe:
    "M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0 M3 12h18 M12 3c-5 5-5 13 0 18 5-5 5-13 0-18",
  users:
    "M16 21v-3a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v3 M9 10a4 4 0 1 0 0-8 4 4 0 0 0 0 8 M17 3a4 4 0 0 1 0 8 M22 21v-3a4 4 0 0 0-3-4",
  lock: "M5 10h14v11H5z M8 10V7a4 4 0 0 1 8 0v3 M12 14v3",
  settings: "M4 7h16 M4 17h16 M8 4v6 M16 14v6",
  clock: "M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0 M12 7v5l3 2",
  search: "M17 10a7 7 0 1 1-14 0 7 7 0 0 1 14 0 m-2 5 6 6",
  arrow: "M4 12h16 m-6-6 6 6-6 6",
  chevron: "m9 5 7 7-7 7",
  refresh: "M20 8a8 8 0 1 0 0 8 M20 3v5h-5",
  plus: "M12 4v16 M4 12h16",
  logout: "M9 3H3v18h6 M9 12h12 m-5-5 5 5-5 5",
  flask: "M9 3h6 M10 3v6L4 20h16L14 9V3 M7 14h10",
  server: "M3 3h18v7H3z M3 14h18v7H3z M7 6h.01 M7 17h.01",
  menu: "M4 6h16 M4 12h16 M4 18h16",
  close: "m6 6 12 12 M18 6 6 18",
} as const;

export type IconName = keyof typeof paths;

export function Icon({
  name,
  size = 20,
  className,
  style,
}: {
  name: IconName;
  size?: number;
  className?: string;
  style?: CSSProperties;
}) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.65"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      className={className}
      style={style}
    >
      <path d={paths[name]} />
    </svg>
  );
}

export function navigationIcon(href: string): IconName {
  if (href === "/") return "dashboard";
  if (href.includes("health") || href.includes("providers")) return "activity";
  if (href.includes("translation")) return "language";
  if (href.includes("review")) return "check";
  if (href.includes("reports")) return "report";
  if (href.includes("imports")) return "upload";
  if (href.includes("sources")) return "globe";
  if (href.includes("support") || href.includes("roles")) return "users";
  if (href.includes("sessions")) return "lock";
  if (href.includes("audit") || href.includes("versions")) return "clock";
  if (href.includes("flags")) return "settings";
  return href.includes("terminology") || href.includes("lesson")
    ? "book"
    : "layers";
}

export function BrandMark() {
  return (
    <span className="brand-mark" aria-hidden="true">
      <svg width="26" height="26" viewBox="0 0 28 28" fill="none">
        <path d="M11 3h6v8h8v6h-8v8h-6v-8H3v-6h8V3Z" fill="currentColor" />
        <path
          d="m10 14 3 3 6-7"
          stroke="#125b4c"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </span>
  );
}
