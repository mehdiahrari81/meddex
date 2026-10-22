"use client";

import { useActionState, useState } from "react";
import { login, type LoginState } from "./actions";

const initialState: LoginState = {};

export function LoginForm() {
  const [state, action, pending] = useActionState(login, initialState);
  const [useAuthenticator, setUseAuthenticator] = useState(false);
  return (
    <form
      action={action}
      aria-describedby={state.error ? "login-error" : undefined}
    >
      {state.error ? (
        <div id="login-error" className="error" role="alert">
          {state.error}
        </div>
      ) : null}
      <label>
        Email
        <input
          name="email"
          type="email"
          autoComplete="username"
          placeholder="you@example.com"
          required
        />
      </label>
      <label>
        Password
        <input
          name="password"
          type="password"
          autoComplete="current-password"
          placeholder="Enter your password"
          required
        />
      </label>
      <button
        type="button"
        className="authenticator-toggle"
        aria-expanded={useAuthenticator}
        aria-controls="authenticator-fields"
        onClick={() => setUseAuthenticator((visible) => !visible)}
      >
        {useAuthenticator
          ? "Hide authenticator code"
          : "Use an authenticator code"}
      </button>
      <div id="authenticator-fields" hidden={!useAuthenticator}>
        {useAuthenticator && (
          <label>
            MFA code
            <input
              name="mfaCode"
              inputMode="numeric"
              autoComplete="one-time-code"
              pattern="[0-9]{6}"
              maxLength={6}
              placeholder="6-digit authenticator code"
              required
            />
          </label>
        )}
      </div>
      <button disabled={pending}>
        {pending ? "Signing in…" : "Sign in securely"}
      </button>
    </form>
  );
}
