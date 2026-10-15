import { groceryParts } from "@recipes/schema/lib";
import type { GroceryItem } from "@recipes/schema";
import { MoreHorizontal, ShoppingBasket, Trash2 } from "lucide-react";
import { useState, type FormEvent } from "react";
import { EmptyState, useToast } from "../components/ui.js";
import { api } from "../lib/api.js";
import { useLibrary } from "../lib/library.js";
import { Link, recipesUrl } from "../lib/router.js";

export function GroceriesPage() {
  const { groceries, recipe, refresh, setGroceries } = useLibrary();
  const { toast } = useToast();
  const [text, setText] = useState("");
  const waiting = groceries.filter((item) => !item.isChecked);
  const done = groceries.filter((item) => item.isChecked);

  const report = (caught: unknown) => toast(caught instanceof Error ? caught.message : "Something went wrong.");

  const add = async (event: FormEvent) => {
    event.preventDefault();
    const line = text.trim();
    if (!line) return;
    try {
      const added = await api.groceries.add([groceryParts(line)]);
      setText("");
      await refresh();
      if (added.length === 0) toast("That's already on your list");
    } catch (caught) {
      report(caught);
    }
  };

  const toggle = async (item: GroceryItem) => {
    setGroceries((items) => items.map((candidate) => (candidate.id === item.id ? { ...candidate, isChecked: !item.isChecked } : candidate)));
    try {
      await api.groceries.patch(item.id, { isChecked: !item.isChecked });
    } catch (caught) {
      report(caught);
    }
    await refresh();
  };

  const remove = async (item: GroceryItem) => {
    try {
      await api.groceries.remove(item.id);
      await refresh();
    } catch (caught) {
      report(caught);
    }
  };

  const clear = async (scope: "completed" | "all") => {
    if (scope === "all" && !window.confirm("Remove every item from your grocery list?")) return;
    try {
      await api.groceries.clear(scope);
      await refresh();
    } catch (caught) {
      report(caught);
    }
  };

  const row = (item: GroceryItem) => {
    const from = recipe(item.recipeID);
    return (
      <li key={item.id} className={item.isChecked ? "checked" : ""}>
        <label className="check">
          <input type="checkbox" checked={item.isChecked} onChange={() => void toggle(item)} />
          <span>
            {item.quantity && <strong>{item.quantity} </strong>}
            {item.name}
          </span>
        </label>
        {from && (
          <Link to={recipesUrl({ id: from.id })} className="muted small from">
            {from.title}
          </Link>
        )}
        <button type="button" className="icon-button" aria-label={`Remove ${item.name}`} onClick={() => void remove(item)}>
          <Trash2 size={15} />
        </button>
      </li>
    );
  };

  return (
    <div className="page narrow">
      <header className="page-head">
        <h1 className="serif">Groceries</h1>
        <div className="spacer" />
        <details className="menu">
          <summary className="icon-button" aria-label="Grocery list actions">
            <MoreHorizontal size={18} />
          </summary>
          <div className="menu-items right" onClick={(event) => (event.currentTarget.parentElement as HTMLDetailsElement).removeAttribute("open")}>
            <button type="button" disabled={done.length === 0} onClick={() => void clear("completed")}>
              Clear completed
            </button>
            <button type="button" className="danger" disabled={groceries.length === 0} onClick={() => void clear("all")}>
              Clear all
            </button>
          </div>
        </details>
      </header>

      <form onSubmit={add} className="add-grocery">
        <input value={text} onChange={(e) => setText(e.target.value)} placeholder="Add an item, like “2 cups flour”" aria-label="Add a grocery item" />
        <button type="submit" className="primary" disabled={!text.trim()}>
          Add
        </button>
      </form>

      {groceries.length === 0 ? (
        <EmptyState icon={<ShoppingBasket size={36} />} title="Your list is empty">
          Add items above, or use “Groceries” on a recipe to add its ingredients.
        </EmptyState>
      ) : (
        <>
          <ul className="grocery-list">{waiting.map(row)}</ul>
          {done.length > 0 && (
            <>
              <h2 className="small-heading">Done</h2>
              <ul className="grocery-list">{done.map(row)}</ul>
            </>
          )}
        </>
      )}
    </div>
  );
}
