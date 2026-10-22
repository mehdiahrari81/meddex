import { cookies } from "next/headers";
import { redirect } from "next/navigation";

export const COOKIE_NAME = "mediexplain_admin";
const API_URL = process.env.MEDIEXPLAIN_API_URL ?? "http://localhost:8000/api/v1";

export type AdminMe = {
  user_id: string;
  email: string;
  role: string;
  permissions: string[];
  session_id: string;
  local_self_review_allowed?: boolean;
};

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export async function adminToken(): Promise<string | null> {
  return (await cookies()).get(COOKIE_NAME)?.value ?? null;
}

export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const token = await adminToken();
  if (!token) redirect("/login");
  const response = await request(path, {
    ...init,
    cache: "no-store",
    headers: {
      Accept: "application/json",
      ...(init?.body && !(init.body instanceof FormData) ? { "Content-Type": "application/json" } : {}),
      Authorization: `Bearer ${token}`,
      ...init?.headers,
    },
  });
  if (response.status === 401) redirect("/login?expired=1");
  if (!response.ok) {
    throw new ApiError(response.status, await errorMessage(response));
  }
  if (response.status === 204) return undefined as T;
  return (await response.json()) as T;
}

export async function currentAdmin(): Promise<AdminMe> {
  return api<AdminMe>("/admin/me");
}

export async function anonymousApi<T>(path: string, init: RequestInit): Promise<T> {
  const response = await request(path, {
    ...init,
    cache: "no-store",
    headers: { "Content-Type": "application/json", Accept: "application/json", ...init.headers },
  });
  if (!response.ok) {
    throw new ApiError(response.status, "Sign-in was not accepted.");
  }
  return (await response.json()) as T;
}

async function request(path: string, init: RequestInit): Promise<Response> {
  try {
    return await fetch(`${API_URL}${path}`, {
      ...init,
      signal: init.signal ?? AbortSignal.timeout(15_000),
    });
  } catch {
    throw new ApiError(503, "The service is temporarily unavailable. Please try again.");
  }
}

async function errorMessage(response: Response): Promise<string> {
  try {
    const body = await response.json() as { detail?: unknown; error?: { message?: unknown } };
    if (typeof body.error?.message === "string") return body.error.message;
    if (typeof body.detail === "string") return body.detail;
  } catch {}
  return response.status === 403
    ? "Your account does not have permission to perform this action."
    : "The operation could not be completed. Check your input and try again.";
}
