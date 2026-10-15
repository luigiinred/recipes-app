import type { ApiToken } from "@recipes/schema";
import { Copy, Download, KeyRound, LogOut, Trash2, Upload } from "lucide-react";
import { useEffect, useRef, useState, type FormEvent } from "react";
import { ErrorNote, useAction, useToast } from "../components/ui.js";
import { api } from "../lib/api.js";
import { MEAL_NAMES, mealTitle } from "../lib/format.js";
import { useLibrary } from "../lib/library.js";
import { setPref, usePrefs } from "../lib/prefs.js";

export function SettingsPage({ version, onSignedOut }: { version: string; onSignedOut: () => void }) {
  const prefs = usePrefs();
  return (
    <div className="page narrow settings">
      <header className="page-head">
        <h1 className="serif">Settings</h1>
        <div className="spacer" />
        <button
          type="button"
          onClick={async () => {
            await api.logout();
            onSignedOut();
          }}
        >
          <LogOut size={16} /> Sign out
        </button>
      </header>

      <section className="card stack">
        <h2>This browser</h2>
        <label>
          Rate recipes with
          <select value={prefs.ratingStyle} onChange={(e) => setPref("ratingStyle", e.target.value as "favorites" | "stars")}>
            <option value="favorites">Favorites (a heart)</option>
            <option value="stars">Star ratings (one to five)</option>
          </select>
        </label>
        <label>
          Recipe list
          <select value={prefs.listStyle} onChange={(e) => setPref("listStyle", e.target.value as "list" | "cards")}>
            <option value="list">Compact list</option>
            <option value="cards">Photo cards</option>
          </select>
        </label>
        <label>
          Week starts on
          <select value={prefs.weekStart} onChange={(e) => setPref("weekStart", Number(e.target.value) as 0 | 1)}>
            <option value={0}>Sunday</option>
            <option value={1}>Monday</option>
          </select>
        </label>
        <label>
          Meal for new plans
          <select value={prefs.defaultMeal} onChange={(e) => setPref("defaultMeal", e.target.value as typeof prefs.defaultMeal)}>
            <option value="automatic">Based on the time of day</option>
            {MEAL_NAMES.map((meal) => (
              <option key={meal} value={meal}>
                {mealTitle(meal)}
              </option>
            ))}
          </select>
        </label>
        <label className="check">
          <input type="checkbox" checked={prefs.keepAwake} onChange={(e) => setPref("keepAwake", e.target.checked)} />
          <span>Keep the screen awake in cook mode</span>
        </label>
      </section>

      <Tokens />
      <Password />
      <Data />

      <p className="muted small">Recipes server {version}</p>
    </div>
  );
}

function Tokens() {
  const [tokens, setTokens] = useState<ApiToken[]>([]);
  const [name, setName] = useState("");
  const [fresh, setFresh] = useState<{ token: string; name: string } | null>(null);
  const { busy, error, run } = useAction();
  const { toast } = useToast();

  const load = () => api.tokens.list().then(setTokens, () => {});
  useEffect(() => void load(), []);

  const create = async (event: FormEvent) => {
    event.preventDefault();
    const result = await run(() => api.tokens.create(name.trim()));
    if (!result) return;
    setFresh({ token: result.token, name: result.info.name });
    setName("");
    await load();
  };

  const revoke = async (token: ApiToken) => {
    if (!window.confirm(`Revoke “${token.name}”? Anything using it will stop syncing.`)) return;
    await run(() => api.tokens.revoke(token.id));
    await load();
  };

  const copy = (text: string) => navigator.clipboard?.writeText(text).then(() => toast("Copied"), () => toast("Couldn't copy. Select it and copy by hand."));

  return (
    <section className="card stack">
      <h2>Connect the iPhone and Mac apps</h2>
      <p className="muted">
        In the app, open Settings → Storage, choose “Self-hosted server”, then enter this address and a token you create here.
      </p>
      <div className="copy-line">
        <code>{window.location.origin}</code>
        <button type="button" className="icon-button" aria-label="Copy server address" onClick={() => copy(window.location.origin)}>
          <Copy size={15} />
        </button>
      </div>

      <form onSubmit={create} className="row">
        <label className="grow">
          New token
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Timmy's iPhone" maxLength={80} required />
        </label>
        <button type="submit" disabled={busy || !name.trim()}>
          <KeyRound size={16} /> Create
        </button>
      </form>
      <ErrorNote message={error} />
      {fresh && (
        <div className="notice">
          <p>
            Token for <strong>{fresh.name}</strong>. Copy it now. It isn't shown again.
          </p>
          <div className="copy-line">
            <code>{fresh.token}</code>
            <button type="button" className="icon-button" aria-label="Copy token" onClick={() => copy(fresh.token)}>
              <Copy size={15} />
            </button>
          </div>
        </div>
      )}
      {tokens.length > 0 && (
        <ul className="token-list">
          {tokens.map((token) => (
            <li key={token.id}>
              <div>
                <strong>{token.name}</strong>
                <span className="muted small">
                  Created {new Date(token.createdAt).toLocaleDateString()} · {token.lastUsedAt ? `used ${new Date(token.lastUsedAt).toLocaleString()}` : "never used"}
                </span>
              </div>
              <button type="button" className="icon-button" aria-label={`Revoke ${token.name}`} onClick={() => void revoke(token)}>
                <Trash2 size={15} />
              </button>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

function Password() {
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [again, setAgain] = useState("");
  const { busy, error, run, setError } = useAction();
  const { toast } = useToast();

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (next !== again) return setError("The new passwords don't match.");
    if ((await run(() => api.changePassword(current, next))) !== undefined) {
      setCurrent("");
      setNext("");
      setAgain("");
      toast("Password changed. Other browsers were signed out.");
    }
  };

  return (
    <form className="card stack" onSubmit={submit}>
      <h2>Password</h2>
      <label>
        Current password
        <input type="password" value={current} onChange={(e) => setCurrent(e.target.value)} autoComplete="current-password" required />
      </label>
      <label>
        New password <span className="muted">(at least 8 characters)</span>
        <input type="password" value={next} onChange={(e) => setNext(e.target.value)} autoComplete="new-password" minLength={8} required />
      </label>
      <label>
        New password again
        <input type="password" value={again} onChange={(e) => setAgain(e.target.value)} autoComplete="new-password" required />
      </label>
      <ErrorNote message={error} />
      <div className="row">
        <button type="submit" disabled={busy}>
          Change password
        </button>
      </div>
    </form>
  );
}

function Data() {
  const { refresh, recipes } = useLibrary();
  const { busy, error, run } = useAction();
  const { toast } = useToast();
  const file = useRef<HTMLInputElement>(null);

  const restore = async (selected: File | undefined) => {
    if (!selected) return;
    const result = await run(async () => api.restore(JSON.parse(await selected.text())));
    if (file.current) file.current.value = "";
    if (!result) return;
    await refresh();
    toast(`Restored ${result.recipes} recipes, ${result.mealPlan} planned meals and ${result.groceries} grocery items`);
  };

  return (
    <section className="card stack">
      <h2>Your data</h2>
      <p className="muted">
        {recipes.length} recipe{recipes.length === 1 ? "" : "s"} live as plain files in the server's data folder. This export is the same document the apps'
        “Export all data” makes, so it works in both directions.
      </p>
      <div className="row">
        <a className="button" href="/api/export" download>
          <Download size={16} /> Download everything
        </a>
        <input ref={file} type="file" accept="application/json,.json" hidden onChange={(e) => void restore(e.target.files?.[0])} />
        <button type="button" disabled={busy} onClick={() => file.current?.click()}>
          <Upload size={16} /> {busy ? "Restoring…" : "Restore from an export"}
        </button>
      </div>
      <ErrorNote message={error} />
    </section>
  );
}
