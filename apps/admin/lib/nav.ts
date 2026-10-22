export type NavItem = { label: string; href: string; permission: string };
export type NavGroup = { title: string; items: NavItem[] };

export const navigation: NavGroup[] = [
  {
    title: "Overview",
    items: [
      { label: "Dashboard", href: "/", permission: "system.read" },
      { label: "System health", href: "/system-health", permission: "system.read" },
      { label: "Provider status", href: "/providers", permission: "system.read" },
    ],
  },
  {
    title: "Medical content",
    items: [
      { label: "Terminology", href: "/content/terminology", permission: "content.read" },
      { label: "Morphology", href: "/content/morphology", permission: "content.read" },
      { label: "Abbreviations", href: "/content/abbreviation", permission: "content.read" },
      { label: "Learning content", href: "/content/lesson", permission: "content.read" },
      { label: "Flashcards", href: "/content/flashcard", permission: "content.read" },
      { label: "Quiz management", href: "/content/quiz", permission: "content.read" },
      { label: "Translation review", href: "/content/translation", permission: "content.read" },
      { label: "Review queue", href: "/review", permission: "content.review" },
      { label: "Content versions", href: "/versions", permission: "content.read" },
      { label: "Reference releases", href: "/content/dataset", permission: "content.read" },
    ],
  },
  {
    title: "Safety & sources",
    items: [
      { label: "Content reports", href: "/reports", permission: "reports.review" },
      { label: "AI safety reports", href: "/reports?type=unsafe_ai", permission: "reports.review" },
      { label: "Medication resolution", href: "/resolution-review", permission: "sources.manage" },
      { label: "Imports", href: "/imports", permission: "sources.manage" },
      { label: "Source details", href: "/sources", permission: "sources.manage" },
    ],
  },
  {
    title: "Security",
    items: [
      { label: "User support", href: "/user-support", permission: "users.support_read" },
      { label: "Roles & permissions", href: "/roles", permission: "system.manage" },
      { label: "Sessions", href: "/sessions", permission: "system.manage" },
      { label: "Audit logs", href: "/audit", permission: "audit.read" },
      { label: "Feature flags", href: "/feature-flags", permission: "system.read" },
    ],
  },
];

export function permittedNavigation(permissions: string[]): NavGroup[] {
  const set = new Set(permissions);
  return navigation
    .map((group) => ({ ...group, items: group.items.filter((item) => set.has(item.permission)) }))
    .filter((group) => group.items.length > 0);
}
