import { groceryParts, ingredientAmount, ingredientName, ingredientPreparation, isIdea, parseIngredient } from "@recipes/schema/lib";
import type { RecipeView } from "@recipes/schema";
import {
  CalendarPlus,
  ChefHat,
  Clock,
  ExternalLink,
  ListPlus,
  ListTodo,
  MoreHorizontal,
  Pencil,
  Play,
  Printer,
  ShoppingBasket,
  Trash2,
  Users,
} from "lucide-react";
import { useState } from "react";
import { api, stepImageUrl } from "../lib/api.js";
import { addDays, clock, dayKey, formatMinutes, MEAL_NAMES, mealForHour, mealTitle, safeHref, youTubeID, type Meal } from "../lib/format.js";
import { useLibrary } from "../lib/library.js";
import { Link, navigate, recipesUrl } from "../lib/router.js";
import { usePrefs } from "../lib/prefs.js";
import { Rating } from "./Rating.js";
import { ErrorNote, Modal, Photo, useAction, useToast } from "./ui.js";

function ingredientGroups(recipe: RecipeView): { title?: string; items: { index: number; text: string }[] }[] {
  const starts = [...recipe.ingredientSections].sort((a, b) => a.start - b.start);
  const boundaries = starts.map((section) => section.start);
  if (boundaries[0] !== 0) boundaries.unshift(0);
  const groups: { title?: string; items: { index: number; text: string }[] }[] = [];
  boundaries.forEach((begin, position) => {
    const end = boundaries[position + 1] ?? recipe.ingredients.length;
    if (begin >= end || begin < 0 || end > recipe.ingredients.length) return;
    const title = [...starts].reverse().find((section) => section.start === begin)?.title;
    groups.push({ title, items: Array.from({ length: end - begin }, (_, i) => ({ index: begin + i, text: recipe.ingredients[begin + i]! })) });
  });
  return groups;
}

export function IngredientLine({ text }: { text: string }) {
  const parsed = parseIngredient(text);
  const amount = ingredientAmount(parsed);
  if (!amount) return <>{text}</>;
  const preparation = ingredientPreparation(parsed);
  return (
    <>
      <strong>{amount}</strong> {ingredientName(parsed)}
      {preparation && (
        <>
          , <em className="prep">{preparation}</em>
        </>
      )}
    </>
  );
}

export function RecipeDetail({ recipe }: { recipe: RecipeView }) {
  const { adopt, refresh } = useLibrary();
  const { toast } = useToast();
  const [planning, setPlanning] = useState(false);
  const [start, setStart] = useState<number | null>(null);
  const idea = isIdea(recipe);
  const video = youTubeID(recipe.sourceURL);
  const source = safeHref(recipe.sourceURL);

  const toggleQueue = async () => {
    try {
      adopt(await api.recipes.patch(recipe.id, { wantToCook: !recipe.wantToCook }));
      toast(recipe.wantToCook ? "Removed from Up Next" : "Added to Up Next");
    } catch (caught) {
      toast(caught instanceof Error ? caught.message : "Couldn't update Up Next.");
    }
  };

  const addToGroceries = async () => {
    const items = recipe.ingredients.map((line) => ({ ...groceryParts(line), recipeID: recipe.id }));
    try {
      const added = await api.groceries.add(items);
      await refresh();
      toast(added.length === 0 ? "Those are already on your list" : `Added ${added.length} item${added.length === 1 ? "" : "s"} to Groceries`);
    } catch (caught) {
      toast(caught instanceof Error ? caught.message : "Couldn't add to groceries.");
    }
  };

  const remove = async () => {
    if (!window.confirm(`Delete “${recipe.title}”? This can't be undone.`)) return;
    try {
      await api.recipes.remove(recipe.id);
      await refresh();
      navigate("/recipes");
    } catch (caught) {
      toast(caught instanceof Error ? caught.message : "Couldn't delete that.");
    }
  };

  return (
    <article className="recipe">
      {video ? (
        <div className="video">
          <iframe
            key={start ?? "idle"}
            src={`https://www.youtube-nocookie.com/embed/${video}?rel=0${start === null ? "" : `&start=${start}&autoplay=1`}`}
            title={recipe.title}
            allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
            allowFullScreen
            referrerPolicy="strict-origin-when-cross-origin"
          />
        </div>
      ) : (
        recipe.imageVersion !== null && <Photo recipe={recipe} className="hero" />
      )}

      <header className="recipe-head">
        <h1 className="serif">{recipe.title}</h1>
        {recipe.summary && <p className="summary serif">{recipe.summary}</p>}
        <ul className="facts">
          {recipe.servings != null && (
            <li>
              <Users size={15} /> Serves {recipe.servings}
            </li>
          )}
          {recipe.prepMinutes != null && (
            <li>
              <Clock size={15} /> Prep {formatMinutes(recipe.prepMinutes)}
            </li>
          )}
          {recipe.cookMinutes != null && (
            <li>
              <ChefHat size={15} /> Cook {formatMinutes(recipe.cookMinutes)}
            </li>
          )}
        </ul>
        {recipe.tags.length > 0 && (
          <ul className="chips">
            {recipe.tags.map((tag) => (
              <li key={tag}>
                <Link to={recipesUrl({ tag })} className="chip">
                  {tag.split("/").join(" › ")}
                </Link>
              </li>
            ))}
          </ul>
        )}
        <div className="actions no-print">
          <Rating recipe={recipe} />
          {!idea && (
            <Link to={`/recipes/${recipe.id}/cook`} className="button primary">
              <Play size={16} /> Cook
            </Link>
          )}
          <button type="button" onClick={() => void toggleQueue()} aria-pressed={recipe.wantToCook} className={recipe.wantToCook ? "toggled" : ""}>
            <ListPlus size={16} /> {recipe.wantToCook ? "In Up Next" : "Up Next"}
          </button>
          <button type="button" onClick={() => setPlanning(true)}>
            <CalendarPlus size={16} /> Plan
          </button>
          {!idea && (
            <button type="button" onClick={() => void addToGroceries()}>
              <ShoppingBasket size={16} /> Groceries
            </button>
          )}
          <details className="menu">
            <summary className="icon-button" aria-label="More actions">
              <MoreHorizontal size={18} />
            </summary>
            <div className="menu-items" onClick={(event) => (event.currentTarget.parentElement as HTMLDetailsElement).removeAttribute("open")}>
              <Link to={`/recipes/${recipe.id}/edit`}>
                <Pencil size={15} /> Edit
              </Link>
              <button type="button" onClick={() => window.print()}>
                <Printer size={15} /> Print
              </button>
              <button type="button" className="danger" onClick={() => void remove()}>
                <Trash2 size={15} /> Delete
              </button>
            </div>
          </details>
        </div>
      </header>

      <div className="recipe-body">
        {idea && (
          <section aria-labelledby="idea-h">
            <h2 id="idea-h">Just an idea so far</h2>
            <p className="muted">
              Add ingredients and steps when you have a recipe for it, and this becomes a full recipe. <Link to={`/recipes/${recipe.id}/edit`}>Add them now</Link>.
            </p>
          </section>
        )}
        {recipe.ingredients.length > 0 && (
          <section className="ingredients" aria-labelledby="ingredients-h">
            <h2 id="ingredients-h">Ingredients</h2>
            {ingredientGroups(recipe).map((group, i) => (
              <div key={i} className="ingredient-group">
                {group.title && <h3>{group.title}</h3>}
                <ul>
                  {group.items.map((item) => (
                    <li key={item.index} className="serif">
                      <IngredientLine text={item.text} />
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </section>
        )}

        {recipe.steps.length > 0 && (
          <section className="steps" aria-labelledby="steps-h">
            <h2 id="steps-h">Steps</h2>
            <ol>
              {recipe.steps.map((step, index) => {
                const time = recipe.stepTimestamps[index];
                const photo = recipe.stepImages[index];
                return (
                  <li key={index} className="serif">
                    <p>
                      {step}
                      {video && time != null && (
                        <button type="button" className="timestamp no-print" onClick={() => setStart(time)}>
                          <Play size={11} /> {clock(time)}
                        </button>
                      )}
                    </p>
                    {photo && <img className="step-photo" src={stepImageUrl(photo)} alt="" loading="lazy" />}
                  </li>
                );
              })}
            </ol>
          </section>
        )}
      </div>

      {recipe.notes && (
        <section className="notes">
          <h2>Notes</h2>
          <p className="serif pre">{recipe.notes}</p>
        </section>
      )}
      {source && (
        <p className="source muted">
          <ListTodo size={14} /> Source:{" "}
          <a href={source} target="_blank" rel="noopener noreferrer">
            {new URL(source).hostname.replace(/^www\./, "")} <ExternalLink size={12} />
          </a>
        </p>
      )}

      {planning && <PlanDialog recipe={recipe} onClose={() => setPlanning(false)} />}
    </article>
  );
}

function PlanDialog({ recipe, onClose }: { recipe: RecipeView; onClose: () => void }) {
  const { refresh } = useLibrary();
  const { toast } = useToast();
  const prefs = usePrefs();
  const [day, setDay] = useState(dayKey(new Date()));
  const [meal, setMeal] = useState<Meal>(prefs.defaultMeal === "automatic" ? mealForHour(new Date().getHours()) : prefs.defaultMeal);
  const { busy, error, run } = useAction();

  const quickDays = [0, 1, 2].map((offset) => dayKey(addDays(new Date(), offset)));
  const save = async () => {
    const result = await run(() => api.plan.create({ recipeID: recipe.id, title: recipe.title, day, meal }));
    if (!result) return;
    await refresh();
    toast(`Planned for ${day}`);
    onClose();
  };

  return (
    <Modal title={`Plan “${recipe.title}”`} onClose={onClose}>
      <div className="stack">
        <label>
          Day
          <input type="date" value={day} onChange={(e) => setDay(e.target.value)} required />
        </label>
        <div className="row">
          {quickDays.map((key, i) => (
            <button key={key} type="button" className={day === key ? "toggled" : ""} onClick={() => setDay(key)}>
              {["Today", "Tomorrow", "Day after"][i]}
            </button>
          ))}
        </div>
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
        <ErrorNote message={error} />
        <div className="row end">
          <button type="button" onClick={onClose}>
            Cancel
          </button>
          <button type="button" className="primary" disabled={busy || !day} onClick={() => void save()}>
            Add to plan
          </button>
        </div>
      </div>
    </Modal>
  );
}
