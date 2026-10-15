import { filterCollection, recipeMatches } from "@recipes/schema/lib";
import type { MealPlanEntry, RecipeView } from "@recipes/schema";
import { ArrowDown, ArrowUp, CalendarDays, ChevronLeft, ChevronRight, ListPlus, Pencil, Plus, Trash2, X } from "lucide-react";
import { useMemo, useState } from "react";
import { EmptyState, ErrorNote, Modal, useAction, useToast } from "../components/ui.js";
import { api } from "../lib/api.js";
import { addDays, dateFromKey, dayKey, MEAL_NAMES, mealForHour, mealTitle, startOfWeek, type Meal } from "../lib/format.js";
import { useLibrary } from "../lib/library.js";
import { usePrefs } from "../lib/prefs.js";
import { Link, recipesUrl } from "../lib/router.js";

const dayHeading = new Intl.DateTimeFormat(undefined, { weekday: "short", month: "short", day: "numeric" });
const rangeHeading = new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric" });

export function PlanPage() {
  const { recipes, plan, refresh } = useLibrary();
  const prefs = usePrefs();
  const { toast } = useToast();
  const [anchor, setAnchor] = useState(() => startOfWeek(new Date(), prefs.weekStart));
  const [adding, setAdding] = useState<{ day: string; recipe?: RecipeView } | null>(null);
  const [editing, setEditing] = useState<MealPlanEntry | null>(null);

  const weekStart = startOfWeek(anchor, prefs.weekStart);
  const days = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));
  const today = dayKey(new Date());
  const queue = useMemo(() => filterCollection(recipes, "up-next"), [recipes]);
  const byDay = useMemo(() => {
    const map = new Map<string, MealPlanEntry[]>();
    for (const entry of plan) map.set(entry.day, [...(map.get(entry.day) ?? []), entry]);
    for (const list of map.values()) list.sort((a, b) => MEAL_NAMES.indexOf(a.meal) - MEAL_NAMES.indexOf(b.meal));
    return map;
  }, [plan]);

  const report = (caught: unknown) => toast(caught instanceof Error ? caught.message : "Something went wrong.");

  const unqueue = async (recipe: RecipeView) => {
    try {
      await api.recipes.patch(recipe.id, { wantToCook: false });
      await refresh();
    } catch (caught) {
      report(caught);
    }
  };

  // Renumbers the queue times of the recipes that moved, so the order sticks.
  const move = async (index: number, by: -1 | 1) => {
    const target = index + by;
    if (target < 0 || target >= queue.length) return;
    const ordered = [...queue];
    [ordered[index], ordered[target]] = [ordered[target]!, ordered[index]!];
    const base = Math.min(...queue.map((recipe) => Date.parse(recipe.queuedAt ?? recipe.createdAt)));
    try {
      await Promise.all(
        ordered.map((recipe, i) => {
          const time = new Date(base + i * 1000).toISOString().replace(/\.\d{3}Z$/, "Z");
          return recipe.queuedAt === time ? undefined : api.recipes.update(recipe.id, { ...recipe, queuedAt: time });
        }),
      );
      await refresh();
    } catch (caught) {
      report(caught);
    }
  };

  const removeEntry = async (entry: MealPlanEntry) => {
    try {
      await api.plan.remove(entry.id);
      await refresh();
    } catch (caught) {
      report(caught);
    }
  };

  return (
    <div className="page wide">
      <header className="page-head">
        <h1 className="serif">Plan</h1>
      </header>

      <div className="plan-layout">
        <section className="queue" aria-labelledby="queue-h">
          <h2 id="queue-h">Up Next</h2>
          {queue.length === 0 ? (
            <EmptyState icon={<ListPlus size={30} />} title="Nothing queued">
              Add recipes you mean to cook soon from their page.
            </EmptyState>
          ) : (
            <ol className="queue-list">
              {queue.map((recipe, index) => (
                <li key={recipe.id}>
                  <Link to={recipesUrl({ id: recipe.id })} className="serif">
                    {recipe.title}
                  </Link>
                  <div className="row-tools">
                    <button type="button" className="icon-button" aria-label={`Move ${recipe.title} up`} disabled={index === 0} onClick={() => void move(index, -1)}>
                      <ArrowUp size={15} />
                    </button>
                    <button type="button" className="icon-button" aria-label={`Move ${recipe.title} down`} disabled={index === queue.length - 1} onClick={() => void move(index, 1)}>
                      <ArrowDown size={15} />
                    </button>
                    <button type="button" className="icon-button" aria-label={`Plan ${recipe.title}`} onClick={() => setAdding({ day: today, recipe })}>
                      <CalendarDays size={15} />
                    </button>
                    <button type="button" className="icon-button" aria-label={`Remove ${recipe.title} from Up Next`} onClick={() => void unqueue(recipe)}>
                      <X size={15} />
                    </button>
                  </div>
                </li>
              ))}
            </ol>
          )}
        </section>

        <section className="week" aria-labelledby="week-h">
          <div className="week-head">
            <h2 id="week-h">
              {rangeHeading.format(days[0]!)} – {rangeHeading.format(days[6]!)}
            </h2>
            <div className="spacer" />
            <button type="button" className="icon-button" aria-label="Previous week" onClick={() => setAnchor(addDays(weekStart, -7))}>
              <ChevronLeft size={18} />
            </button>
            <button type="button" onClick={() => setAnchor(startOfWeek(new Date(), prefs.weekStart))}>
              Today
            </button>
            <button type="button" className="icon-button" aria-label="Next week" onClick={() => setAnchor(addDays(weekStart, 7))}>
              <ChevronRight size={18} />
            </button>
          </div>
          <div className="days">
            {days.map((date) => {
              const key = dayKey(date);
              const entries = byDay.get(key) ?? [];
              return (
                <div key={key} className={`day ${key === today ? "today" : ""}`}>
                  <header>
                    <h3>{dayHeading.format(date)}</h3>
                    <button type="button" className="icon-button" aria-label={`Add a meal on ${dayHeading.format(date)}`} onClick={() => setAdding({ day: key })}>
                      <Plus size={16} />
                    </button>
                  </header>
                  {entries.length === 0 && <p className="muted small">Nothing planned</p>}
                  <ul>
                    {entries.map((entry) => (
                      <li key={entry.id}>
                        <span className="meal-label">{mealTitle(entry.meal)}</span>
                        {entry.recipeID ? (
                          <Link to={recipesUrl({ id: entry.recipeID })} className="serif">
                            {entry.title}
                          </Link>
                        ) : (
                          <span className="serif">{entry.title}</span>
                        )}
                        <div className="row-tools">
                          <button type="button" className="icon-button" aria-label={`Change ${entry.title}`} onClick={() => setEditing(entry)}>
                            <Pencil size={14} />
                          </button>
                          <button type="button" className="icon-button" aria-label={`Remove ${entry.title}`} onClick={() => void removeEntry(entry)}>
                            <Trash2 size={14} />
                          </button>
                        </div>
                      </li>
                    ))}
                  </ul>
                </div>
              );
            })}
          </div>
        </section>
      </div>

      {adding && <AddMealDialog day={adding.day} recipe={adding.recipe} onClose={() => setAdding(null)} />}
      {editing && <EditMealDialog entry={editing} onClose={() => setEditing(null)} />}
    </div>
  );
}

function MealFields({ day, setDay, meal, setMeal }: { day: string; setDay: (day: string) => void; meal: Meal; setMeal: (meal: Meal) => void }) {
  return (
    <div className="row">
      <label>
        Day
        <input type="date" value={day} onChange={(e) => setDay(e.target.value)} required />
      </label>
      <label>
        Meal
        <select value={meal} onChange={(e) => setMeal(e.target.value as Meal)}>
          {MEAL_NAMES.map((name) => (
            <option key={name} value={name}>
              {mealTitle(name)}
            </option>
          ))}
        </select>
      </label>
    </div>
  );
}

function AddMealDialog({ day: initialDay, recipe: initialRecipe, onClose }: { day: string; recipe?: RecipeView; onClose: () => void }) {
  const { recipes, refresh } = useLibrary();
  const prefs = usePrefs();
  const [day, setDay] = useState(initialDay);
  const [meal, setMeal] = useState<Meal>(prefs.defaultMeal === "automatic" ? mealForHour(new Date().getHours()) : prefs.defaultMeal);
  const [chosen, setChosen] = useState<RecipeView | undefined>(initialRecipe);
  const [custom, setCustom] = useState("");
  const [query, setQuery] = useState("");
  const { busy, error, run } = useAction();
  const matches = useMemo(() => recipes.filter((recipe) => recipeMatches(recipe, query)).slice(0, 30), [recipes, query]);

  const save = async () => {
    const title = chosen?.title ?? custom.trim();
    if (!title) return;
    const result = await run(() => api.plan.create({ recipeID: chosen?.id, title, day, meal }));
    if (result) {
      await refresh();
      onClose();
    }
  };

  return (
    <Modal title="Add a meal" onClose={onClose}>
      <div className="stack">
        <MealFields day={day} setDay={setDay} meal={meal} setMeal={setMeal} />
        {chosen ? (
          <p className="chosen serif">
            {chosen.title}{" "}
            <button type="button" className="icon-button" aria-label="Choose a different recipe" onClick={() => setChosen(undefined)}>
              <X size={14} />
            </button>
          </p>
        ) : (
          <>
            <label>
              Pick a recipe
              <input type="search" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search your recipes" />
            </label>
            <ul className="pick-list">
              {matches.map((recipe) => (
                <li key={recipe.id}>
                  <button type="button" className="serif" onClick={() => setChosen(recipe)}>
                    {recipe.title}
                  </button>
                </li>
              ))}
            </ul>
            <label>
              …or type a meal
              <input value={custom} onChange={(e) => setCustom(e.target.value)} placeholder="Leftovers, takeout…" />
            </label>
          </>
        )}
        <ErrorNote message={error} />
        <div className="row end">
          <button type="button" onClick={onClose}>
            Cancel
          </button>
          <button type="button" className="primary" disabled={busy || (!chosen && !custom.trim()) || !day} onClick={() => void save()}>
            Add
          </button>
        </div>
      </div>
    </Modal>
  );
}

function EditMealDialog({ entry, onClose }: { entry: MealPlanEntry; onClose: () => void }) {
  const { refresh } = useLibrary();
  const [day, setDay] = useState(entry.day);
  const [meal, setMeal] = useState<Meal>(entry.meal);
  const { busy, error, run } = useAction();
  const save = async () => {
    const result = await run(() => api.plan.update(entry.id, { recipeID: entry.recipeID, title: entry.title, day, meal }));
    if (result) {
      await refresh();
      onClose();
    }
  };
  return (
    <Modal title={entry.title} onClose={onClose}>
      <div className="stack">
        <MealFields day={day} setDay={setDay} meal={meal} setMeal={setMeal} />
        <ErrorNote message={error} />
        <div className="row end">
          <button type="button" onClick={onClose}>
            Cancel
          </button>
          <button type="button" className="primary" disabled={busy || !dateFromKey(day)} onClick={() => void save()}>
            Save
          </button>
        </div>
      </div>
    </Modal>
  );
}
