"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";
import { anonymousApi, api, ApiError, COOKIE_NAME } from "@/lib/api";

const schema = z.object({
  email: z.email(),
  password: z.string().min(1).max(128),
  mfaCode: z.string().regex(/^\d{6}$/).or(z.literal("")),
});

export type LoginState = { error?: string };

export async function login(
  _state: LoginState,
  formData: FormData,
): Promise<LoginState> {
  const parsed = schema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
    mfaCode: formData.get("mfaCode") ?? "",
  });
  if (!parsed.success) {
    return {
      error: parsed.error.issues.some((issue) => issue.path[0] === "mfaCode")
        ? "Enter a six-digit authenticator code."
        : "Enter a valid email and password.",
    };
  }
  try {
    const session = await anonymousApi<{
      access_token: string;
      access_token_expires_at: string;
    }>("/admin/auth/login", {
      method: "POST",
      body: JSON.stringify({
        email: parsed.data.email,
        password: parsed.data.password,
        mfa_code: parsed.data.mfaCode || null,
      }),
    });
    const store = await cookies();
    store.set(COOKIE_NAME, session.access_token, {
      httpOnly: true,
      sameSite: "strict",
      secure: process.env.ADMIN_COOKIE_SECURE !== "false",
      path: "/",
      expires: new Date(session.access_token_expires_at),
    });
  } catch (error) {
    return {
      error:
        error instanceof ApiError && error.status === 503
          ? error.message
          : parsed.data.mfaCode
            ? "Sign-in was not accepted. Check your email, password, and authenticator code."
            : "Sign-in was not accepted. Check your email and password.",
    };
  }
  redirect("/");
}

export async function logout(): Promise<void> {
  try {
    await api<void>("/admin/auth/logout", { method: "POST" });
  } catch {
    // The local cookie is still removed if the API session already expired.
  }
  const store = await cookies();
  store.delete(COOKIE_NAME);
  redirect("/login");
}
