import { test, expect, type Page } from "@playwright/test";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

async function signIn(page: Page, email = "admin@example.com") {
  await page.goto("/login");
  await page.getByLabel("Email", { exact: true }).fill(email);
  await page.getByLabel("Password", { exact: true }).fill("BrowserTest!1234");
  await page.getByRole("button", { name: "Sign in securely" }).click();
  await expect(page).not.toHaveURL(/\/login(?:\?.*)?$/);
}

test("login hydrates under CSP and logout revokes the session", async ({
  page,
  context,
}) => {
  const violations: string[] = [];
  page.on("console", (message) => {
    if (/content security policy|refused to execute/i.test(message.text()))
      violations.push(message.text());
  });
  await page.goto("/login");
  await expect(page.getByLabel("MFA code", { exact: true })).toHaveCount(0);
  await page.getByRole("button", { name: "Use an authenticator code" }).click();
  await expect(page.getByLabel("MFA code", { exact: true })).toBeVisible();
  await page.getByLabel("MFA code", { exact: true }).fill("123456");
  await page.getByRole("button", { name: "Hide authenticator code" }).click();
  await expect(page.getByLabel("MFA code", { exact: true })).toHaveCount(0);
  await page.getByLabel("Email", { exact: true }).fill("admin@example.com");
  await page.getByLabel("Password", { exact: true }).fill("WrongPassword!123");
  await page.getByRole("button", { name: "Sign in securely" }).click();
  await expect(page.locator("#login-error")).toHaveText(
    "Sign-in was not accepted. Check your email and password.",
  );
  await signIn(page);
  await expect(
    page.getByRole("heading", { name: "Governance dashboard" }),
  ).toBeVisible();
  const cookie = (await context.cookies()).find(
    (item) => item.name === "mediexplain_admin",
  );
  expect(cookie?.httpOnly).toBe(true);
  expect(cookie?.sameSite).toBe("Strict");
  expect(
    await page
      .locator("script:not([src])")
      .evaluateAll((scripts) =>
        scripts.every((script) => Boolean((script as HTMLScriptElement).nonce)),
      ),
  ).toBe(true);
  expect(violations).toEqual([]);
  await page.getByRole("button", { name: "Sign out", exact: true }).click();
  await expect(page).toHaveURL(/\/login$/);
  await page.goto("/imports");
  await expect(page).toHaveURL(/\/login$/);
});

test("editor lands on an allowed page and support can open the dashboard", async ({
  page,
}) => {
  await signIn(page, "editor@example.com");
  await expect(page).toHaveURL(/\/content\/terminology$/);
  await expect(
    page.getByRole("link", { name: "Audit logs", exact: true }),
  ).toHaveCount(0);
  await page.getByRole("button", { name: "Sign out", exact: true }).click();
  await signIn(page, "support@example.com");
  await expect(
    page.getByRole("heading", { name: "Governance dashboard" }),
  ).toBeVisible();
});

test("CSV dry run and confirmed apply work with recoverable validation errors", async ({
  page,
}) => {
  await signIn(page);
  await page.goto("/imports");
  await page
    .getByLabel("Authoritative source name")
    .fill("Reviewed browser fixture");
  await page.getByLabel("Source version").fill("browser-v1");
  await page.getByLabel("CSV dataset").setInputFiles({
    name: "products.csv",
    mimeType: "text/csv",
    buffer: Buffer.from(
      "Registration Number,Brand Name,Composition,Dosage Form\nBROWSER-1,Test product,Test ingredient 10mg,tablet\n",
    ),
  });
  await page
    .getByRole("button", { name: "Validate dataset", exact: true })
    .click();
  const success = page.getByRole("status");
  await expect(success).toContainText("Validation passed");
  const job = (await success.innerText()).match(
    /[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}/,
  )?.[0];
  expect(job).toBeTruthy();
  await page.getByLabel("Validated job ID", { exact: true }).fill(job!);
  await page.getByLabel("Repeat job ID to confirm").fill(job!);
  await page.getByRole("button", { name: "Apply reviewed import" }).click();
  await expect(page.getByRole("status").last()).toContainText(
    "applied successfully",
  );
  await page.getByRole("button", { name: "Apply reviewed import" }).click();
  await expect(page.getByRole("alert")).toBeVisible();
  await expect(page.getByLabel("Authoritative source name")).toBeVisible();
});

test("all administrator navigation pages load real API data", async ({
  page,
}) => {
  await signIn(page);
  await expect(
    page.getByRole("heading", { name: "Governance dashboard" }),
  ).toBeVisible();
  const paths = await page
    .locator("nav a")
    .evaluateAll(
      (links) =>
        [...new Set(links.map((link) => link.getAttribute("href")))].filter(
          Boolean,
        ) as string[],
    );
  for (const route of paths) {
    const response = await page.goto(route);
    expect(response?.status(), route).toBe(200);
    await expect(
      page.getByRole("heading", { name: "Could not load this page" }),
    ).toHaveCount(0);
    await expect(page.locator("main h1")).toBeVisible();
  }
});

test("a reference release can be inspected, independently approved, and published", async ({
  page,
  request,
}) => {
  const document = JSON.parse(
    readFileSync(
      path.resolve("../mobile/assets/terminology/starter_dataset_v1.json"),
      "utf8",
    ),
  );
  document.dataset_version = "browser-reviewed-release-v2";
  await signIn(page, "editor@example.com");
  await page.goto("/content/dataset/new");
  await page.getByLabel("Reference dataset file").setInputFiles({
    name: "reviewed-release.json", mimeType: "application/json", buffer: Buffer.from(JSON.stringify(document)),
  });
  await expect(page.getByRole("status")).toContainText("browser-reviewed-release-v2");
  await page.getByLabel("Source or publisher").fill("Browser review fixture");
  const stableId = await page.locator('input[name="stableId"]').inputValue();
  expect(stableId).toMatch(/^dataset\./);
  await page
    .getByLabel("Change reason")
    .fill("Reference release browser verification");
  await page.getByRole("button", { name: "Save draft revision" }).click();
  await expect(page).toHaveURL(/\/content\/dataset$/);
  await page
    .getByRole("link", { name: stableId, exact: true }).first()
    .click();
  await expect(
    page.getByRole("heading", { name: "Source attribution" }),
  ).toBeVisible();
  await expect(
    page.getByText("Browser review fixture", { exact: true }),
  ).toBeVisible();
  await page
    .getByLabel("Reason", { exact: true })
    .fill("Ready for independent review");
  await page.getByLabel("I confirm this action for this record").check();
  await page.locator('form input[name="actionKind"][value="content"]').locator("..").getByRole("button").click();
  await expect(
    page.getByRole("heading", { name: "Revision 1 · in_review" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Sign out", exact: true }).click();
  await signIn(page, "reviewer@example.com");
  await page.goto(`/content/dataset/${stableId}`);
  await expect(
    page.getByRole("link", { name: "Create revised draft" }),
  ).toHaveCount(0);
  for (const action of ["approve", "publish"]) {
    await page
      .getByRole("combobox", { name: "Action", exact: true })
      .selectOption(action);
    await page
      .getByLabel("Reason", { exact: true })
      .fill("Independently reviewed fixture and source attribution");
    await page.getByLabel("I confirm this action for this record").check();
    await page.locator('form input[name="actionKind"][value="content"]').locator("..").getByRole("button").click();
    await expect(
      page.getByRole("heading", {
        name: `Revision 1 · ${action === "approve" ? "approved" : "published"}`,
      }),
    ).toBeVisible();
  }
  const response = await request.get(
    "http://127.0.0.1:18080/api/v1/content/dataset",
  );
  expect(response.ok()).toBe(true);
  expect((await response.json()).dataset_version).toMatch(/^publication-/);
});

test("small screens have a usable menu and contained tables", async ({
  page,
}, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await signIn(page);
  const toggle = page.getByRole("button", { name: "Open menu", exact: true });
  await expect(toggle).toBeVisible();
  await expect(
    page.getByRole("link", { name: "Imports", exact: true }),
  ).toBeHidden();
  await toggle.click();
  await page.getByRole("link", { name: "Imports", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Import jobs" }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Open menu", exact: true }),
  ).toBeVisible();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
  await page.screenshot({
    path: testInfo.outputPath("admin-mobile.png"),
    fullPage: true,
  });
});

test("dashboard totals, activity periods, and recent-content filters use persisted records", async ({
  page,
  context,
  request,
}) => {
  await signIn(page);
  await expect(
    page.getByText("FYP demo workspace", { exact: true }),
  ).toBeVisible();
  const token = (await context.cookies()).find(
    (cookie) => cookie.name === "mediexplain_admin",
  )!.value;
  const response = await request.get(
    "http://127.0.0.1:18080/api/v1/admin/dashboard",
    { headers: { Authorization: `Bearer ${token}` } },
  );
  const snapshot = await response.json();
  await expect(
    page
      .locator(".metric-card")
      .filter({ hasText: "Content records" })
      .locator(".metric-value"),
  ).toHaveText(String(snapshot.content.total));
  await page.getByLabel("Activity period").selectOption("14");
  await expect(page).toHaveURL(/days=14/);
  await expect(
    page.getByRole("img", { name: /editorial events over 14 days/ }),
  ).toBeVisible();
  await page.getByRole("button", { name: "In review", exact: true }).click();
  await expect(page.locator(".content-table tbody tr").first()).toBeVisible();
  const badges = await page
    .locator(".content-table tbody .status")
    .allTextContents();
  expect(badges.every((label) => label === "in review")).toBe(true);
  await page.getByRole("button", { name: "Refresh", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Governance dashboard" }),
  ).toBeVisible();
  await page.setViewportSize({ width: 390, height: 844 });
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBe(true);
});

test("workspace search, table filtering, and pagination work", async ({
  page,
}) => {
  await signIn(page);
  const search = page.getByLabel("Find an administration page");
  await search.fill("Imports");
  await search.press("Enter");
  await expect(page).toHaveURL(/\/imports$/);
  await page
    .getByRole("searchbox", { name: "Search records", exact: true })
    .fill("missing_registration_id");
  await expect(page.locator(".records-panel tbody tr")).toHaveCount(1);
  await page.goto("/versions");
  await expect(page.locator(".records-panel tbody tr")).toHaveCount(10);
  await page.getByRole("button", { name: "Next", exact: true }).click();
  await expect(page.locator(".records-panel .panel-footer")).toContainText(
    "11–20",
  );
  await page
    .getByRole("searchbox", { name: "Search records", exact: true })
    .fill("term-hypertension");
  await expect(page.locator(".records-panel tbody tr")).toHaveCount(1);
});

test("dashboard report links prefill an audited resolution and update the totals", async ({
  page,
}) => {
  await signIn(page);
  const before = Number(
    await page
      .locator(".metric-card")
      .filter({ hasText: "Reports to resolve" })
      .locator(".metric-value")
      .innerText(),
  );
  await page.locator(".report-item").first().click();
  const id = await page.getByLabel("Report ID", { exact: true }).inputValue();
  expect(id).toMatch(/^[0-9a-f-]{36}$/);
  await page
    .getByRole("combobox", { name: "Status", exact: true })
    .selectOption("resolved");
  await page
    .getByLabel("Resolution note", { exact: true })
    .fill("Resolved the synthetic report during browser verification.");
  await page.getByLabel("Type report ID to confirm", { exact: true }).fill(id);
  await page.getByRole("button", { name: "Apply audited resolution" }).click();
  await expect(page.getByRole("status")).toContainText(
    "completed successfully",
  );
  await page.goto("/");
  await expect(
    page
      .locator(".metric-card")
      .filter({ hasText: "Reports to resolve" })
      .locator(".metric-value"),
  ).toHaveText(String(before - 1));
});


test("a lesson created in the editor is published to the mobile dataset", async ({ page, request }) => {
  await signIn(page, "editor@example.com");
  await page.goto("/content/lesson/new");
  await page.getByLabel("Title", { exact: true }).fill("Publication pipeline verification lesson");
  await page.getByLabel("Description", { exact: true }).fill("An isolated engineering check of source-backed learning content delivery.");
  await page.getByLabel("Learning objectives (one per line)").fill("Inspect a reference source\nReview published educational content");
  await page.getByRole("button", { name: "Add section", exact: true }).click();
  await page.getByLabel("Section 1 title").fill("Check the information source");
  await page.getByLabel("Section 1 text").fill("Review the reference source and ask a healthcare professional about unclear medical information.");
  await page.getByLabel("Category", { exact: true }).selectOption("general");
  await page.getByLabel("Reference source", { exact: true }).selectOption("src-mediexplain-dev-v1");
  await page.getByLabel("Change reason").fill("Verify admin-to-mobile publishing in isolated test storage");
  const stableId = await page.locator('input[name="stableId"]').inputValue();
  const id = JSON.parse(await page.locator('input[name="content"]').inputValue()).id;
  expect(id).toMatch(/^lesson-/);
  await expect(page.getByLabel("Record ID", { exact: true })).toHaveCount(0);
  await expect(page.getByText("Versioned content JSON", { exact: true })).toHaveCount(0);
  await page.getByRole("button", { name: "Save draft revision" }).click();
  await expect(page).toHaveURL(/\/content\/lesson$/);
  const before = await (await request.get("http://127.0.0.1:18080/api/v1/content/dataset")).json();
  expect(before.lessons.some((lesson: {id: string}) => lesson.id === id)).toBe(false);
  await page.goto(`/content/lesson/${stableId}`);
  await page.getByLabel("Reason", { exact: true }).fill("Ready for independent test review");
  await page.getByLabel("I confirm this action for this record").check();
  await page.locator('form input[name="actionKind"][value="content"]').locator("..").getByRole("button").click();
  await expect(page.getByRole("heading", { name: "Revision 1 · in_review" })).toBeVisible();
  await page.getByRole("button", { name: "Sign out", exact: true }).click();
  await signIn(page, "reviewer@example.com");
  await page.goto(`/content/lesson/${stableId}`);
  for (const action of ["approve", "publish"]) {
    await page.getByRole("combobox", { name: "Action", exact: true }).selectOption(action);
    await page.getByLabel("Reason", { exact: true }).fill("Review source-backed content delivery fixture");
    await page.getByLabel("I confirm this action for this record").check();
    await page.locator('form input[name="actionKind"][value="content"]').locator("..").getByRole("button").click();
    await expect(page.getByRole("heading", { name: `Revision 1 · ${action === "approve" ? "approved" : "published"}` })).toBeVisible();
  }
  const response = await request.get("http://127.0.0.1:18080/api/v1/content/dataset");
  expect(response.ok()).toBe(true);
  const published = await response.json();
  const lesson = published.lessons.find((row: {id: string}) => row.id === id);
  expect(lesson.title).toBe("Publication pipeline verification lesson");
  expect(lesson.objectives).toHaveLength(2);
  expect(lesson.sections).toHaveLength(1);
  expect(published.lessons.length).toBe(before.lessons.length + 1);
  writeFileSync("/tmp/meddex-admin-published-fixture.json", JSON.stringify(published));
});

for (const type of ["terminology", "translation", "morphology", "abbreviation", "flashcard", "quiz"]) {
  test(`${type} can be added, edited and published without writing JSON`, async ({ page, request }) => {
    await signIn(page, "editor@example.com");
    await page.goto(`/content/${type}/new`);
    await expect(page.locator('textarea[name="content"], textarea[name="sourceMetadata"]')).toHaveCount(0);
    if (type === "terminology" || type === "translation") {
      await page.getByLabel("Medical term", { exact: true }).fill(`Form verification ${type}`);
      await page.getByLabel("Simple definition", { exact: true }).fill("A definition entered through the plain-language form in an isolated test.");
      await page.getByText("More definitions and search names (optional)", { exact: true }).click();
      await page.getByLabel("Other names (one per line)", { exact: true }).fill("First name\n\nSecond name\n");
      if (type === "translation") await page.getByLabel("Language", { exact: true }).selectOption("ur");
    } else if (type === "morphology") {
      await page.getByLabel("Word part type", { exact: true }).selectOption("prefix");
      await page.getByLabel("Word part", { exact: true }).fill("form-check-");
      await page.getByLabel("Meaning", { exact: true }).fill("Isolated interface verification");
      await page.getByLabel("Simple explanation", { exact: true }).fill("A test fixture for the word-part form, not clinical reference content.");
      await page.getByLabel("Topic", { exact: true }).fill("Engineering verification");
    } else if (type === "abbreviation") {
      await page.getByLabel("Abbreviation", { exact: true }).fill("FORM");
      await page.getByLabel("Full meaning", { exact: true }).fill("Form workflow verification");
      await page.getByLabel("Related medical term", { exact: true }).selectOption("term-hypertension");
      await page.getByLabel("Where it is used", { exact: true }).fill("Isolated browser tests only");
      await page.getByLabel("Topic", { exact: true }).fill("Engineering verification");
      await page.getByLabel("This abbreviation can have more than one meaning").check();
      await page.getByLabel("Other possible meanings (one per line)").fill("Another test-only meaning");
    } else if (type === "flashcard") {
      await page.getByLabel("Front", { exact: true }).fill("Where does published content appear?");
      await page.getByLabel("Back", { exact: true }).fill("In the mobile reference library after a refresh.");
      await page.getByLabel("Related medical term (optional)").selectOption("term-hypertension");
    } else {
      await page.getByLabel("Question", { exact: true }).fill("Which action makes a reviewed draft available to mobile?");
      await page.getByLabel("Explanation of the correct answer").fill("Only publication updates the shared reference release.");
      await page.getByLabel("Answer 1", { exact: true }).fill("Save draft");
      await page.getByLabel("Answer 2", { exact: true }).fill("Publish");
      await page.getByRole("button", { name: "Add answer", exact: true }).click();
      await page.getByLabel("Answer 3", { exact: true }).fill("Discard");
      await page.getByLabel("Answer 3 is correct", { exact: true }).check();
      await page.getByRole("button", { name: "Remove answer 3", exact: true }).click();
      await page.getByLabel("Answer 2 is correct", { exact: true }).check();
    }
    if (!["morphology", "abbreviation"].includes(type)) await page.getByLabel("Category", { exact: true }).selectOption("general");
    if (type !== "abbreviation") await page.getByLabel("Reference source", { exact: true }).selectOption("src-mediexplain-dev-v1");
    const stableId = await page.locator('input[name="stableId"]').inputValue();
    const original = JSON.parse(await page.locator('input[name="content"]').inputValue());
    expect(stableId).toBe(`${type}.${original.id}`);
    if (type === "quiz") {
      expect(original.options).toHaveLength(2);
      expect(original.options.filter((option: {correct: boolean}) => option.correct)).toHaveLength(1);
      expect(original.options[1].correct).toBe(true);
    }
    await page.getByRole("button", { name: "Save draft revision" }).click();
    await expect(page).toHaveURL(new RegExp(`/content/${type}$`));
    await page.goto(`/content/${type}/${stableId}`);
    await expect(page.getByRole("heading", { name: "Content", exact: true })).toBeVisible();
    await expect(page.locator("pre.code").first()).toBeHidden();
    await page.getByRole("link", { name: "Create revised draft" }).click();
    const revised = JSON.parse(await page.locator('input[name="content"]').inputValue());
    expect(revised).toEqual(original);
    expect(await page.locator('input[name="stableId"]').inputValue()).toBe(stableId);
    await page.getByLabel("Change reason", { exact: true }).fill("Verify edits preserve generated IDs and content relationships");
    await page.getByRole("button", { name: "Save draft revision" }).click();
    await expect(page).toHaveURL(new RegExp(`/content/${type}$`));
    await page.goto(`/content/${type}/${stableId}`);
    await page.getByLabel("Reason", { exact: true }).fill("Ready for independent verification");
    await page.getByLabel("I confirm this action for this record").check();
    await page.locator('form input[name="actionKind"][value="content"]').locator("..").getByRole("button").click();
    await expect(page.getByRole("heading", { name: "Revision 2 · in_review" })).toBeVisible();
    await page.getByRole("button", { name: "Sign out", exact: true }).click();
    await signIn(page, "reviewer@example.com");
    await page.goto(`/content/${type}/${stableId}`);
    for (const action of ["approve", "publish"]) {
      await page.getByLabel("Action", { exact: true }).selectOption(action);
      await page.getByLabel("Reason", { exact: true }).fill("Verify source and structured content from the simple form");
      await page.getByLabel("I confirm this action for this record").check();
      await page.locator('form input[name="actionKind"][value="content"]').locator("..").getByRole("button").click();
      await expect(page.getByRole("heading", { name: `Revision 2 · ${action === "approve" ? "approved" : "published"}` })).toBeVisible();
    }
    const response = await request.get("http://127.0.0.1:18080/api/v1/content/dataset");
    expect(response.ok()).toBe(true);
    const published = await response.json();
    const collection = ({ terminology: "terms", translation: "terms", morphology: "morphology", abbreviation: "abbreviations", flashcard: "flashcards", quiz: "quiz_questions" } as Record<string, string>)[type];
    const item = published[collection].find((row: {id: string}) => row.id === original.id);
    expect(item).toBeTruthy();
    if (type === "terminology" || type === "translation") {
      expect(item.definitions.standard).toBe(original.definitions.simple);
      expect(item.definitions.technical).toBe(original.definitions.simple);
      expect(item.synonyms).toEqual(["First name", "Second name"]);
    }
    if (type === "quiz") expect(item.options.filter((option: {correct: boolean}) => option.correct)[0].text).toBe("Publish");
  });
}

test("reference uploads recover from invalid files and forms fit small screens", async ({ page }) => {
  await signIn(page, "editor@example.com");
  await page.goto("/content/dataset/new");
  await page.getByLabel("Reference dataset file").setInputFiles({ name: "broken.json", mimeType: "application/json", buffer: Buffer.from("{broken") });
  await expect(page.locator(".error[role=alert]")).toContainText("could not be read");
  await expect(page.getByRole("button", { name: "Save draft revision" })).toBeDisabled();
  await page.getByLabel("Reference dataset file").setInputFiles(path.resolve("../mobile/assets/terminology/starter_dataset_v1.json"));
  await expect(page.locator(".error[role=alert]")).toHaveCount(0);
  await expect(page.getByRole("status")).toContainText("terms");
  await page.setViewportSize({ width: 390, height: 844 });
  for (const type of ["lesson", "morphology", "abbreviation", "quiz"]) {
    await page.goto(`/content/${type}/new`);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  }
});
