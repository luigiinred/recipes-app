import { ingredientAmount, ingredientName, ingredientPreparation, parseIngredient } from "@recipes/schema/lib";
import { ArrowLeft, ArrowRight, ListChecks, Timer, X } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Link, navigate, recipesUrl } from "../lib/router.js";
import { clock, findTimers } from "../lib/format.js";
import { useLibrary } from "../lib/library.js";
import { usePrefs } from "../lib/prefs.js";
import { stepImageUrl } from "../lib/api.js";

interface RunningTimer {
  id: number;
  label: string;
  endsAt: number;
  done: boolean;
}

function beep() {
  try {
    const context = new AudioContext();
    for (let i = 0; i < 3; i += 1) {
      const oscillator = context.createOscillator();
      const gain = context.createGain();
      oscillator.frequency.value = 880;
      gain.gain.value = 0.15;
      oscillator.connect(gain).connect(context.destination);
      oscillator.start(context.currentTime + i * 0.5);
      oscillator.stop(context.currentTime + i * 0.5 + 0.25);
    }
    window.setTimeout(() => void context.close(), 2000);
  } catch {
    /* no audio available */
  }
}

/** One screen per step, large type, timers found in the step text. */
export function CookPage({ id }: { id: string }) {
  const { recipe: lookup, loaded } = useLibrary();
  const prefs = usePrefs();
  const recipe = lookup(id);
  const [page, setPage] = useState(0);
  const [timers, setTimers] = useState<RunningTimer[]>([]);
  const [now, setNow] = useState(() => Date.now());
  const counter = useRef(0);

  const pages = recipe ? 1 + recipe.steps.length : 0;
  const exit = useCallback(() => navigate(recipesUrl({ id })), [id]);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "ArrowRight") setPage((p) => Math.min(p + 1, Math.max(pages - 1, 0)));
      if (event.key === "ArrowLeft") setPage((p) => Math.max(p - 1, 0));
      if (event.key === "Escape") exit();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [pages, exit]);

  useEffect(() => {
    if (!prefs.keepAwake || !("wakeLock" in navigator)) return;
    let lock: WakeLockSentinel | null = null;
    let cancelled = false;
    const acquire = () =>
      navigator.wakeLock.request("screen").then(
        (sentinel) => {
          if (cancelled) void sentinel.release();
          else lock = sentinel;
        },
        () => {},
      );
    void acquire();
    const onVisible = () => document.visibilityState === "visible" && void acquire();
    document.addEventListener("visibilitychange", onVisible);
    return () => {
      cancelled = true;
      document.removeEventListener("visibilitychange", onVisible);
      void lock?.release();
    };
  }, [prefs.keepAwake]);

  useEffect(() => {
    if (timers.length === 0) return;
    const tick = window.setInterval(() => {
      const current = Date.now();
      setNow(current);
      setTimers((list) => {
        let rang = false;
        const next = list.map((timer) => {
          if (!timer.done && timer.endsAt <= current) {
            rang = true;
            return { ...timer, done: true };
          }
          return timer;
        });
        if (rang) beep();
        return rang ? next : list;
      });
    }, 500);
    return () => window.clearInterval(tick);
  }, [timers.length]);

  const start = (label: string, seconds: number) => {
    counter.current += 1;
    const entry: RunningTimer = { id: counter.current, label, endsAt: Date.now() + seconds * 1000, done: false };
    setNow(Date.now());
    setTimers((list) => [...list, entry]);
  };

  const step = recipe && page > 0 ? recipe.steps[page - 1] : undefined;
  const stepTimers = useMemo(() => (step ? findTimers(step) : []), [step]);

  if (!recipe) {
    return (
      <div className="center-screen">
        <p className="muted">{loaded ? "That recipe isn't here." : "Loading…"}</p>
        <Link to="/recipes">Back to your recipes</Link>
      </div>
    );
  }

  const photo = page > 0 ? recipe.stepImages[page - 1] : null;

  return (
    <div className="cook">
      <header className="cook-head">
        <button type="button" className="icon-button" onClick={exit} aria-label="Leave cook mode">
          <X size={22} />
        </button>
        <div className="cook-title serif">{recipe.title}</div>
        <span className="muted">
          {page === 0 ? "Ingredients" : `Step ${page} of ${recipe.steps.length}`}
        </span>
      </header>
      <progress className="cook-progress" value={page} max={Math.max(pages - 1, 1)} aria-hidden="true" />

      <div className="cook-body">
        {page === 0 ? (
          <div className="cook-ingredients serif">
            <h2>
              <ListChecks size={26} /> Ingredients
            </h2>
            <ul>
              {recipe.ingredients.map((line, i) => {
                const parsed = parseIngredient(line);
                const amount = ingredientAmount(parsed);
                const prep = ingredientPreparation(parsed);
                return (
                  <li key={i}>
                    {amount ? (
                      <>
                        <strong>{amount}</strong> {ingredientName(parsed)}
                        {prep && <em className="prep">, {prep}</em>}
                      </>
                    ) : (
                      line
                    )}
                  </li>
                );
              })}
            </ul>
            {recipe.ingredients.length === 0 && <p className="muted">This recipe has no ingredients listed.</p>}
          </div>
        ) : (
          <div className="cook-step">
            <p className="cook-text serif">{step}</p>
            {photo && <img className="step-photo" src={stepImageUrl(photo)} alt="" />}
            {stepTimers.length > 0 && (
              <div className="row">
                {stepTimers.map((timer, i) => (
                  <button key={i} type="button" className="timer-chip" onClick={() => start(timer.label, timer.seconds)}>
                    <Timer size={18} /> {timer.label}
                  </button>
                ))}
              </div>
            )}
          </div>
        )}
      </div>

      {timers.length > 0 && (
        <ul className="timers" aria-label="Timers">
          {timers.map((timer) => (
            <li key={timer.id} className={timer.done ? "done" : ""}>
              <Timer size={16} />
              <span>{timer.label}</span>
              <strong className="mono">{timer.done ? "Done" : clock(Math.max(0, Math.ceil((timer.endsAt - now) / 1000)))}</strong>
              <button type="button" className="icon-button" aria-label="Dismiss timer" onClick={() => setTimers((list) => list.filter((t) => t.id !== timer.id))}>
                <X size={14} />
              </button>
            </li>
          ))}
        </ul>
      )}

      <footer className="cook-foot">
        <button type="button" disabled={page === 0} onClick={() => setPage((p) => Math.max(p - 1, 0))}>
          <ArrowLeft size={20} /> Back
        </button>
        {page < pages - 1 ? (
          <button type="button" className="primary" onClick={() => setPage((p) => p + 1)}>
            {page === 0 ? "Start cooking" : "Next"} <ArrowRight size={20} />
          </button>
        ) : (
          <button type="button" className="primary" onClick={exit}>
            Done
          </button>
        )}
      </footer>
    </div>
  );
}
