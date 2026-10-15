import { Check, UtensilsCrossed, X } from "lucide-react";
import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from "react";
import type { RecipeView } from "@recipes/schema";
import { recipeImageUrl } from "../lib/api.js";

/** A recipe photo, or the accent-tinted placeholder the apps show when there isn't one. */
export function Photo({ recipe, className = "" }: { recipe: Pick<RecipeView, "id" | "imageVersion">; className?: string }) {
  const url = recipeImageUrl(recipe);
  return url ? (
    <img className={`photo ${className}`} src={url} alt="" loading="lazy" />
  ) : (
    <div className={`photo placeholder ${className}`} aria-hidden="true">
      <UtensilsCrossed size={28} />
    </div>
  );
}

export function Modal({ title, onClose, children, wide = false }: { title: string; onClose: () => void; children: ReactNode; wide?: boolean }) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const dialog = ref.current;
    if (dialog && !dialog.open) dialog.showModal();
    return () => dialog?.close();
  }, []);
  return (
    <dialog
      ref={ref}
      className={`modal ${wide ? "wide" : ""}`}
      onCancel={(event) => {
        event.preventDefault();
        onClose();
      }}
      onMouseDown={(event) => {
        if (event.target === ref.current) onClose();
      }}
      aria-label={title}
    >
      <div className="modal-body">
        <header className="modal-header">
          <h2>{title}</h2>
          <button type="button" className="icon-button" onClick={onClose} aria-label="Close">
            <X size={18} />
          </button>
        </header>
        {children}
      </div>
    </dialog>
  );
}

interface ToastApi {
  toast: (message: string) => void;
}
const ToastContext = createContext<ToastApi>({ toast: () => {} });
export const useToast = (): ToastApi => useContext(ToastContext);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [messages, setMessages] = useState<{ id: number; text: string }[]>([]);
  const counter = useRef(0);
  const toast = useCallback((text: string) => {
    const id = (counter.current += 1);
    setMessages((list) => [...list, { id, text }]);
    window.setTimeout(() => setMessages((list) => list.filter((item) => item.id !== id)), 3500);
  }, []);
  return (
    <ToastContext.Provider value={{ toast }}>
      {children}
      <div className="toasts" role="status" aria-live="polite">
        {messages.map((message) => (
          <div key={message.id} className="toast">
            <Check size={16} /> {message.text}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

/** Runs an async action, reporting its error message instead of throwing into the UI. */
export function useAction() {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const run = useCallback(async <T,>(work: () => Promise<T>): Promise<T | undefined> => {
    setBusy(true);
    setError(null);
    try {
      return await work();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "Something went wrong.");
      return undefined;
    } finally {
      setBusy(false);
    }
  }, []);
  return { busy, error, run, setError };
}

export function ErrorNote({ message }: { message: string | null }) {
  return message ? (
    <p className="error" role="alert">
      {message}
    </p>
  ) : null;
}

export function EmptyState({ icon, title, children }: { icon: ReactNode; title: string; children?: ReactNode }) {
  return (
    <div className="empty">
      <div className="empty-icon">{icon}</div>
      <h3>{title}</h3>
      {children && <p>{children}</p>}
    </div>
  );
}
