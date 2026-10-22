import { describe, expect, it } from "vitest";
import { permittedNavigation } from "./nav";
describe("permission-aware navigation", () => { it("does not expose unauthorized routes", () => { const items = permittedNavigation(["reports.review"]).flatMap((group) => group.items); expect(items.every((item) => item.permission === "reports.review")).toBe(true); expect(items.some((item) => item.href === "/roles")).toBe(false); }); });
