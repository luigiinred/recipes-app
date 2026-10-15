import type { SessionInfo } from "@recipes/schema";
import { useCallback, useEffect, useState } from "react";
import { Shell } from "./components/Shell.js";
import { ToastProvider } from "./components/ui.js";
import { api, AUTH_LOST } from "./lib/api.js";
import { LibraryProvider } from "./lib/library.js";
import { LoginPage, SetupPage } from "./pages/Login.js";

export function App() {
  const [session, setSession] = useState<SessionInfo | null>(null);
  const [failed, setFailed] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setSession(await api.session());
      setFailed(null);
    } catch (caught) {
      setFailed(caught instanceof Error ? caught.message : "Can't reach the server.");
    }
  }, []);

  useEffect(() => {
    void load();
    const lost = () => setSession((current) => (current ? { ...current, authenticated: false } : current));
    window.addEventListener(AUTH_LOST, lost);
    return () => window.removeEventListener(AUTH_LOST, lost);
  }, [load]);

  const signedOut = useCallback(() => setSession((current) => (current ? { ...current, authenticated: false } : current)), []);

  if (failed) {
    return (
      <div className="center-screen">
        <p className="error">{failed}</p>
        <button type="button" onClick={() => void load()}>
          Try again
        </button>
      </div>
    );
  }
  if (!session) return <div className="center-screen muted">Loading…</div>;
  if (session.setupRequired) return <SetupPage onDone={load} />;
  if (!session.authenticated) return <LoginPage onDone={load} />;
  return (
    <ToastProvider>
      <LibraryProvider onSignedOut={signedOut}>
        <Shell version={session.version} onSignedOut={load} />
      </LibraryProvider>
    </ToastProvider>
  );
}
