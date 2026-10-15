import { UtensilsCrossed } from "lucide-react";
import { useState, type FormEvent } from "react";
import { ErrorNote, useAction } from "../components/ui.js";
import { api } from "../lib/api.js";

function Frame({ title, intro, children }: { title: string; intro: string; children: React.ReactNode }) {
  return (
    <div className="center-screen">
      <div className="auth-card">
        <div className="brand-mark">
          <UtensilsCrossed size={30} />
        </div>
        <h1 className="serif">{title}</h1>
        <p className="muted">{intro}</p>
        {children}
      </div>
    </div>
  );
}

export function LoginPage({ onDone }: { onDone: () => void }) {
  const [password, setPassword] = useState("");
  const { busy, error, run } = useAction();
  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if ((await run(() => api.login(password))) !== undefined) onDone();
  };
  return (
    <Frame title="Recipes" intro="Sign in to your library.">
      <form onSubmit={submit} className="stack">
        <label>
          Password
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" autoFocus required />
        </label>
        <ErrorNote message={error} />
        <button type="submit" className="primary" disabled={busy || !password}>
          {busy ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </Frame>
  );
}

export function SetupPage({ onDone }: { onDone: () => void }) {
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [again, setAgain] = useState("");
  const { busy, error, run, setError } = useAction();
  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (password !== again) return setError("The passwords don't match.");
    if ((await run(() => api.setup(code.trim(), password))) !== undefined) onDone();
  };
  return (
    <Frame title="Welcome to Recipes" intro="Choose a password for your server. You'll need the setup code the server printed when it started (it's also in the data folder, in .server/setup-code).">
      <form onSubmit={submit} className="stack">
        <label>
          Setup code
          <input value={code} onChange={(e) => setCode(e.target.value)} autoComplete="off" autoCapitalize="none" spellCheck={false} autoFocus required />
        </label>
        <label>
          Password <span className="muted">(at least 8 characters)</span>
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="new-password" minLength={8} required />
        </label>
        <label>
          Password again
          <input type="password" value={again} onChange={(e) => setAgain(e.target.value)} autoComplete="new-password" required />
        </label>
        <ErrorNote message={error} />
        <button type="submit" className="primary" disabled={busy}>
          {busy ? "Setting up…" : "Create library"}
        </button>
      </form>
    </Frame>
  );
}
