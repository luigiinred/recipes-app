import type { RecipeInput, RecipeView } from "@recipes/schema";
import { ArrowDown, ArrowUp, ImagePlus, Trash2, X } from "lucide-react";
import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { ErrorNote, useAction } from "../components/ui.js";
import { api, recipeImageUrl, stepImageUrl } from "../lib/api.js";
import { clock, dataUrlToBlob, resizePhoto, safeHref, secondsFromClock, youTubeID } from "../lib/format.js";
import { useLibrary } from "../lib/library.js";
import { Link, navigate, recipesUrl, useLocation } from "../lib/router.js";

interface StepDraft {
  text: string;
  time: string;
  image: string | null;
}

interface Draft {
  title: string;
  summary: string;
  servings: string;
  prepMinutes: string;
  cookMinutes: string;
  tags: string;
  /** One ingredient per line; a line starting with "# " is a section heading. */
  ingredients: string;
  steps: StepDraft[];
  notes: string;
  sourceURL: string;
}

const numberOrNull = (text: string): number | null => (/^\d+$/.test(text.trim()) ? Number(text.trim()) : null);

function ingredientsToText(recipe: Pick<RecipeInput, "ingredients" | "ingredientSections">): string {
  const sections = [...(recipe.ingredientSections ?? [])].sort((a, b) => a.start - b.start);
  const lines: string[] = [];
  (recipe.ingredients ?? []).forEach((ingredient, index) => {
    for (const section of sections) if (section.start === index) lines.push(`# ${section.title}`);
    lines.push(ingredient);
  });
  return lines.join("\n");
}

function textToIngredients(text: string): Pick<RecipeInput, "ingredients" | "ingredientSections"> {
  const ingredients: string[] = [];
  const ingredientSections: { title: string; start: number }[] = [];
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (!line) continue;
    if (line.startsWith("#")) {
      const title = line.replace(/^#+\s*/, "").trim();
      if (title) ingredientSections.push({ title, start: ingredients.length });
    } else {
      ingredients.push(line);
    }
  }
  return { ingredients, ingredientSections };
}

function toDraft(recipe: Partial<RecipeInput> | undefined): Draft {
  const steps = recipe?.steps ?? [];
  return {
    title: recipe?.title ?? "",
    summary: recipe?.summary ?? "",
    servings: recipe?.servings?.toString() ?? "",
    prepMinutes: recipe?.prepMinutes?.toString() ?? "",
    cookMinutes: recipe?.cookMinutes?.toString() ?? "",
    tags: (recipe?.tags ?? []).join(", "),
    ingredients: recipe ? ingredientsToText({ ingredients: recipe.ingredients ?? [], ingredientSections: recipe.ingredientSections ?? [] }) : "",
    steps: steps.length > 0
      ? steps.map((text, i) => ({
          text,
          time: recipe?.stepTimestamps?.[i] != null ? clock(recipe.stepTimestamps[i]!) : "",
          image: recipe?.stepImages?.[i] ?? null,
        }))
      : [{ text: "", time: "", image: null }],
    notes: recipe?.notes ?? "",
    sourceURL: recipe?.sourceURL ?? "",
  };
}

interface EditorState {
  draft?: RecipeInput;
  image?: string | null;
}

export function EditorPage({ id }: { id?: string }) {
  const { recipe: lookup, loaded, recipes, adopt, refresh } = useLibrary();
  const { state } = useLocation();
  const imported = (state as EditorState | null) ?? null;
  const existing = id ? lookup(id) : undefined;

  if (id && !existing) {
    return <div className="page">{loaded ? <p className="muted">That recipe isn't here. <Link to="/recipes">Back to your recipes</Link></p> : null}</div>;
  }
  return (
    <Editor
      recipe={existing}
      imported={existing ? null : imported}
      knownTags={[...new Set(recipes.flatMap((recipe) => recipe.tags))]}
      onSaved={async (saved) => {
        adopt(saved);
        await refresh();
        navigate(recipesUrl({ id: saved.id }));
      }}
    />
  );
}

function Editor({
  recipe,
  imported,
  knownTags,
  onSaved,
}: {
  recipe?: RecipeView;
  imported: EditorState | null;
  knownTags: string[];
  onSaved: (recipe: RecipeView) => Promise<void>;
}) {
  const [draft, setDraft] = useState<Draft>(() => toDraft(recipe ?? imported?.draft));
  const [photo, setPhoto] = useState<{ blob: Blob; preview: string } | null>(null);
  const [existingPhoto, setExistingPhoto] = useState<string | null>(recipe ? recipeImageUrl(recipe) : (imported?.image ?? null));
  const [removePhoto, setRemovePhoto] = useState(false);
  // Set once a new recipe has been created, so a retry after a failed photo upload updates it instead of adding a copy.
  const [createdId, setCreatedId] = useState<string | null>(null);
  const { busy, error, run, setError } = useAction();
  const fileInput = useRef<HTMLInputElement>(null);
  const source = recipe?.sourceURL ?? imported?.draft?.sourceURL;
  const isVideo = !!youTubeID(draft.sourceURL || source);

  useEffect(() => () => void (photo && URL.revokeObjectURL(photo.preview)), [photo]);

  const set = <K extends keyof Draft>(key: K, value: Draft[K]) => setDraft((current) => ({ ...current, [key]: value }));
  const setStep = (index: number, patch: Partial<StepDraft>) =>
    set("steps", draft.steps.map((step, i) => (i === index ? { ...step, ...patch } : step)));
  const moveStep = (index: number, by: -1 | 1) => {
    const target = index + by;
    if (target < 0 || target >= draft.steps.length) return;
    const steps = [...draft.steps];
    [steps[index], steps[target]] = [steps[target]!, steps[index]!];
    set("steps", steps);
  };

  const suggestions = useMemo(() => knownTags.sort((a, b) => a.localeCompare(b)), [knownTags]);

  const choosePhoto = async (file: File | undefined) => {
    if (!file) return;
    const blob = await resizePhoto(file);
    setPhoto({ blob, preview: URL.createObjectURL(blob) });
    setRemovePhoto(false);
  };

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (!draft.title.trim()) return setError("Give the recipe a title.");
    const timeTexts = draft.steps.map((step) => step.time.trim());
    if (timeTexts.some((time) => time && secondsFromClock(time) === null)) return setError("Step times look like 1:30.");
    const steps = draft.steps.map((step, i) => ({ ...step, seconds: timeTexts[i] ? secondsFromClock(timeTexts[i]!) : null }));
    const link = draft.sourceURL.trim();
    if (link && !safeHref(link)) return setError("The source should be a web address starting with http:// or https://.");

    const input: RecipeInput = {
      ...(recipe ? { id: recipe.id, createdAt: recipe.createdAt, isFavorite: recipe.isFavorite, rating: recipe.rating, wantToCook: recipe.wantToCook, queuedAt: recipe.queuedAt, imageURL: recipe.imageURL } : { imageURL: imported?.draft?.imageURL }),
      title: draft.title,
      summary: draft.summary,
      servings: numberOrNull(draft.servings),
      prepMinutes: numberOrNull(draft.prepMinutes),
      cookMinutes: numberOrNull(draft.cookMinutes),
      tags: draft.tags.split(",").map((tag) => tag.trim()).filter(Boolean),
      ...textToIngredients(draft.ingredients),
      steps: steps.map((step) => step.text),
      stepTimestamps: steps.some((step) => step.seconds !== null) ? steps.map((step) => step.seconds) : [],
      stepImages: steps.map((step) => step.image),
      notes: draft.notes,
      sourceURL: link || null,
    };

    const saved = await run(async () => {
      const targetId = recipe?.id ?? createdId;
      let result = targetId ? await api.recipes.update(targetId, { ...input, id: targetId }) : await api.recipes.create(input);
      setCreatedId(result.id);
      if (photo) {
        result = await api.recipes.putImage(result.id, photo.blob);
      } else if (removePhoto && recipe) {
        await api.recipes.removeImage(result.id);
        result = { ...result, imageVersion: null };
      } else if (!recipe && imported?.image && result.imageVersion === null) {
        const blob = dataUrlToBlob(imported.image);
        if (blob) result = await api.recipes.putImage(result.id, blob);
      }
      return result;
    });
    if (saved) await onSaved(saved);
  };

  const shownPhoto = removePhoto ? null : (photo?.preview ?? existingPhoto);

  return (
    <form className="page editor" onSubmit={submit}>
      <header className="page-head">
        <h1 className="serif">{recipe ? "Edit recipe" : imported?.draft ? "Review imported recipe" : "New recipe"}</h1>
        <div className="spacer" />
        <Link to={recipe ? recipesUrl({ id: recipe.id }) : "/recipes"} className="button">
          Cancel
        </Link>
        <button type="submit" className="primary" disabled={busy}>
          {busy ? "Saving…" : "Save"}
        </button>
      </header>
      <ErrorNote message={error} />

      <div className="editor-grid">
        <div className="stack">
          <label>
            Title
            <input value={draft.title} onChange={(e) => set("title", e.target.value)} className="serif title-input" autoFocus={!recipe} required />
          </label>
          <label>
            Summary
            <textarea rows={2} value={draft.summary} onChange={(e) => set("summary", e.target.value)} />
          </label>
          <div className="row">
            <label>
              Serves
              <input inputMode="numeric" value={draft.servings} onChange={(e) => set("servings", e.target.value)} />
            </label>
            <label>
              Prep (min)
              <input inputMode="numeric" value={draft.prepMinutes} onChange={(e) => set("prepMinutes", e.target.value)} />
            </label>
            <label>
              Cook (min)
              <input inputMode="numeric" value={draft.cookMinutes} onChange={(e) => set("cookMinutes", e.target.value)} />
            </label>
          </div>
          <label>
            Categories <span className="muted">(comma separated; use Dinner/Pasta to nest)</span>
            <input value={draft.tags} onChange={(e) => set("tags", e.target.value)} list="known-tags" />
            <datalist id="known-tags">
              {suggestions.map((tag) => (
                <option key={tag} value={tag} />
              ))}
            </datalist>
          </label>
          <label>
            Ingredients <span className="muted">(one per line, like “1 1/2 cups flour”. Start a line with # for a heading.)</span>
            <textarea rows={10} value={draft.ingredients} onChange={(e) => set("ingredients", e.target.value)} className="serif" spellCheck={false} />
          </label>
        </div>

        <div className="stack">
          <div className="photo-edit">
            {shownPhoto ? <img src={shownPhoto} alt="Recipe photo" /> : <div className="photo placeholder"><ImagePlus size={28} /></div>}
            <div className="row">
              <input ref={fileInput} type="file" accept="image/*" hidden onChange={(e) => void choosePhoto(e.target.files?.[0])} />
              <button type="button" onClick={() => fileInput.current?.click()}>
                <ImagePlus size={16} /> {shownPhoto ? "Change photo" : "Add photo"}
              </button>
              {shownPhoto && (
                <button
                  type="button"
                  onClick={() => {
                    setPhoto(null);
                    setExistingPhoto(null);
                    setRemovePhoto(true);
                  }}
                >
                  <X size={16} /> Remove
                </button>
              )}
            </div>
          </div>
          <label>
            Source <span className="muted">(web address)</span>
            <input type="url" value={draft.sourceURL} onChange={(e) => set("sourceURL", e.target.value)} placeholder="https://" />
          </label>
          <label>
            Notes
            <textarea rows={5} value={draft.notes} onChange={(e) => set("notes", e.target.value)} className="serif" />
          </label>
        </div>
      </div>

      <section className="step-editor">
        <h2>Steps</h2>
        <ol>
          {draft.steps.map((step, index) => (
            <li key={index}>
              <textarea
                rows={2}
                value={step.text}
                onChange={(e) => setStep(index, { text: e.target.value })}
                aria-label={`Step ${index + 1}`}
                className="serif"
                placeholder="Describe this step"
              />
              <div className="step-tools">
                {isVideo && (
                  <input
                    className="time-input"
                    value={step.time}
                    onChange={(e) => setStep(index, { time: e.target.value })}
                    placeholder="0:00"
                    aria-label={`Video time for step ${index + 1}`}
                  />
                )}
                {step.image && (
                  <span className="step-thumb">
                    <img src={stepImageUrl(step.image)} alt="" />
                    <button type="button" className="icon-button" aria-label="Remove step photo" onClick={() => setStep(index, { image: null })}>
                      <X size={12} />
                    </button>
                  </span>
                )}
                <button type="button" className="icon-button" aria-label="Move step up" disabled={index === 0} onClick={() => moveStep(index, -1)}>
                  <ArrowUp size={16} />
                </button>
                <button type="button" className="icon-button" aria-label="Move step down" disabled={index === draft.steps.length - 1} onClick={() => moveStep(index, 1)}>
                  <ArrowDown size={16} />
                </button>
                <button
                  type="button"
                  className="icon-button"
                  aria-label="Delete step"
                  onClick={() => set("steps", draft.steps.length > 1 ? draft.steps.filter((_, i) => i !== index) : [{ text: "", time: "", image: null }])}
                >
                  <Trash2 size={16} />
                </button>
              </div>
            </li>
          ))}
        </ol>
        <button type="button" onClick={() => set("steps", [...draft.steps, { text: "", time: "", image: null }])}>
          Add step
        </button>
      </section>
    </form>
  );
}
