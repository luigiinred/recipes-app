import { useState } from "react";
import { api } from "../lib/api.js";
import { useLibrary } from "../lib/library.js";
import { navigate, recipesUrl } from "../lib/router.js";
import { ErrorNote, Modal, useAction } from "./ui.js";

/** Jot down something to cook that has no recipe yet, like "Spaghetti" or "Frozen burgers". */
export function NewIdeaDialog({ onClose }: { onClose: () => void }) {
  const { adopt } = useLibrary();
  const [title, setTitle] = useState("");
  const [notes, setNotes] = useState("");
  const { busy, error, run } = useAction();

  const save = async () => {
    const saved = await run(() => api.recipes.create({ title: title.trim(), notes: notes.trim() }));
    if (saved) {
      adopt(saved);
      onClose();
      navigate(recipesUrl({ id: saved.id }));
    }
  };

  return (
    <Modal title="New idea" onClose={onClose}>
      <form
        className="stack"
        onSubmit={(event) => {
          event.preventDefault();
          void save();
        }}
      >
        <label>
          What are you thinking of cooking?
          <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Spaghetti, frozen burgers, leftovers…" autoFocus required />
        </label>
        <label>
          Notes
          <textarea rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} placeholder="Anything to remember" />
        </label>
        <ErrorNote message={error} />
        <div className="row end">
          <button type="button" onClick={onClose}>
            Cancel
          </button>
          <button type="submit" className="primary" disabled={busy || !title.trim()}>
            Save
          </button>
        </div>
      </form>
    </Modal>
  );
}
