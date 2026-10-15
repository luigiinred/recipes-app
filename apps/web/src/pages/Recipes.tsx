import { categoryDisplayName, collectionTitles, COLLECTIONS, filterCategory, filterCollection, recipeMatches, type CollectionId } from "@recipes/schema/lib";
import type { RecipeView } from "@recipes/schema";
import { ArrowLeft, BookOpen, Download, LayoutGrid, List, Plus, Search } from "lucide-react";
import { useEffect, useMemo } from "react";
import { RecipeDetail } from "../components/RecipeDetail.js";
import { RatingBadge } from "../components/Rating.js";
import { EmptyState, Photo } from "../components/ui.js";
import { formatMinutes } from "../lib/format.js";
import { useLibrary } from "../lib/library.js";
import { setPref, usePrefs } from "../lib/prefs.js";
import { Link, navigate, recipesUrl, useLocation } from "../lib/router.js";

export function RecipesPage({ selectedId }: { selectedId?: string }) {
  const { recipes, loaded, error, recipe: lookup, refresh } = useLibrary();
  const { search } = useLocation();
  const prefs = usePrefs();

  const rawCollection = search.get("collection");
  const collection: CollectionId = (COLLECTIONS as readonly string[]).includes(rawCollection ?? "") ? (rawCollection as CollectionId) : "all";
  const tag = search.get("tag") ?? undefined;
  const q = search.get("q") ?? "";

  const visible = useMemo(() => {
    const base = tag ? filterCategory(recipes, tag) : filterCollection(recipes, collection);
    return q ? base.filter((recipe) => recipeMatches(recipe, q)) : base;
  }, [recipes, collection, tag, q]);

  const title = tag ? categoryDisplayName(tag) : collectionTitles[collection];
  const selected = selectedId ? lookup(selectedId) : undefined;
  const context = { collection, tag, q };

  // A link from the apps or another tab may point at a recipe this page hasn't loaded yet.
  useEffect(() => {
    if (loaded && selectedId && !selected) void refresh();
  }, [loaded, selectedId, selected, refresh]);

  const setQuery = (value: string) => navigate(recipesUrl({ ...context, q: value, id: selectedId }), { replace: true });

  return (
    <div className={`split ${selectedId ? "has-selection" : ""}`}>
      <section className="list-pane" aria-label="Recipes">
        <header className="list-head">
          <div className="title-row">
            <h1 className="serif">{title}</h1>
            <span className="muted">{visible.length}</span>
            <div className="spacer" />
            <button
              type="button"
              className="icon-button"
              aria-label={prefs.listStyle === "list" ? "Show photo cards" : "Show compact list"}
              onClick={() => setPref("listStyle", prefs.listStyle === "list" ? "cards" : "list")}
            >
              {prefs.listStyle === "list" ? <LayoutGrid size={18} /> : <List size={18} />}
            </button>
            <details className="menu">
              <summary className="icon-button primary" aria-label="Add a recipe">
                <Plus size={18} />
              </summary>
              <div className="menu-items right" onClick={(event) => (event.currentTarget.parentElement as HTMLDetailsElement).removeAttribute("open")}>
                <Link to="/new">
                  <Plus size={15} /> New recipe
                </Link>
                <Link to="/import">
                  <Download size={15} /> Import from a web page
                </Link>
              </div>
            </details>
          </div>
          <select
            className="collection-picker"
            aria-label="Collection"
            value={tag ? `tag:${tag}` : collection}
            onChange={(event) => {
              const value = event.target.value;
              navigate(value.startsWith("tag:") ? recipesUrl({ tag: value.slice(4) }) : recipesUrl({ collection: value }));
            }}
          >
            {COLLECTIONS.map((id) => (
              <option key={id} value={id}>
                {collectionTitles[id]}
              </option>
            ))}
            {tag && <option value={`tag:${tag}`}>{categoryDisplayName(tag)}</option>}
          </select>
          <label className="search">
            <Search size={16} />
            <input type="search" placeholder="Search recipes" value={q} onChange={(event) => setQuery(event.target.value)} aria-label="Search recipes" />
          </label>
        </header>

        {error && !loaded && <p className="error">{error}</p>}
        {loaded && visible.length === 0 && (
          <EmptyState icon={<BookOpen size={36} />} title={q ? "No matches" : recipes.length === 0 ? "No recipes yet" : "Nothing here yet"}>
            {recipes.length === 0 ? (
              <>
                <Link to="/import">Import one from a web page</Link> or <Link to="/new">write your own</Link>.
              </>
            ) : q ? (
              "Try fewer words."
            ) : (
              "Recipes you file here will show up in this list."
            )}
          </EmptyState>
        )}
        <ul className={`recipe-list ${prefs.listStyle}`}>
          {visible.map((recipe) => (
            <RecipeRow key={recipe.id} recipe={recipe} cards={prefs.listStyle === "cards"} selected={recipe.id === selectedId} to={recipesUrl({ ...context, id: recipe.id })} />
          ))}
        </ul>
      </section>

      {selectedId && (
        <section className="detail-pane" aria-label="Recipe">
          <Link to={recipesUrl(context)} className="back no-print">
            <ArrowLeft size={16} /> {title}
          </Link>
          {selected ? (
            <RecipeDetail key={selected.id} recipe={selected} />
          ) : loaded ? (
            <EmptyState icon={<BookOpen size={36} />} title="That recipe isn't here">
              It may have been deleted. <Link to="/recipes">Back to your recipes</Link>
            </EmptyState>
          ) : null}
        </section>
      )}
      {!selectedId && (
        <section className="detail-pane placeholder-pane" aria-hidden="true">
          <EmptyState icon={<BookOpen size={44} />} title="Pick a recipe" />
        </section>
      )}
    </div>
  );
}

function RecipeRow({ recipe, cards, selected, to }: { recipe: RecipeView; cards: boolean; selected: boolean; to: string }) {
  const minutes = (recipe.prepMinutes ?? 0) + (recipe.cookMinutes ?? 0);
  return (
    <li>
      <Link to={to} className={`recipe-row ${selected ? "selected" : ""}`} aria-current={selected ? "page" : undefined}>
        <Photo recipe={recipe} className={cards ? "card-photo" : "thumb"} />
        <div className="row-text">
          <span className="row-title serif">{recipe.title}</span>
          <span className="row-meta muted">
            {minutes > 0 && <span>{formatMinutes(minutes)}</span>}
            {recipe.tags[0] && <span>{recipe.tags[0].split("/").at(-1)}</span>}
            <RatingBadge recipe={recipe} />
          </span>
        </div>
      </Link>
    </li>
  );
}
