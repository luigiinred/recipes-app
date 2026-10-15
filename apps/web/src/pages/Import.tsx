import { Download } from "lucide-react";
import { useState, type FormEvent } from "react";
import { ErrorNote, useAction } from "../components/ui.js";
import { api } from "../lib/api.js";
import { Link, navigate } from "../lib/router.js";

export function ImportPage() {
  const [url, setUrl] = useState("");
  const { busy, error, run } = useAction();

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    const result = await run(() => api.importUrl(url.trim()));
    if (result) navigate("/new", { state: { draft: result.draft, image: result.image } });
  };

  return (
    <div className="page narrow">
      <header className="page-head">
        <h1 className="serif">Import from the web</h1>
      </header>
      <p className="muted">
        Paste the address of a recipe page. The server reads its recipe data, and you can review it before saving.
      </p>
      <form onSubmit={submit} className="stack">
        <label>
          Page address
          <input type="url" value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://www.example.com/best-cookies" autoFocus required />
        </label>
        <ErrorNote message={error} />
        <div className="row">
          <button type="submit" className="primary" disabled={busy || !url.trim()}>
            <Download size={16} /> {busy ? "Reading the page…" : "Import"}
          </button>
          <Link to="/new" className="button">
            Write one instead
          </Link>
        </div>
      </form>
      <p className="muted small">YouTube videos can be imported in the iPhone and Mac apps.</p>
    </div>
  );
}
