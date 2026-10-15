import type { RecipeView } from "@recipes/schema";
import { Heart, Star } from "lucide-react";
import { api } from "../lib/api.js";
import { useLibrary } from "../lib/library.js";
import { usePrefs } from "../lib/prefs.js";
import { useToast } from "./ui.js";

/** A heart or one-to-five stars, depending on the rating style chosen in Settings. */
export function Rating({ recipe, compact = false }: { recipe: RecipeView; compact?: boolean }) {
  const { adopt } = useLibrary();
  const { toast } = useToast();
  const { ratingStyle } = usePrefs();

  const save = async (patch: { isFavorite: boolean } | { rating: number | null }) => {
    try {
      adopt(await api.recipes.patch(recipe.id, patch));
    } catch (caught) {
      toast(caught instanceof Error ? caught.message : "Couldn't save that.");
    }
  };

  if (ratingStyle === "favorites") {
    return (
      <button
        type="button"
        className={`icon-button heart ${recipe.isFavorite ? "on" : ""}`}
        aria-pressed={recipe.isFavorite}
        aria-label={recipe.isFavorite ? "Remove from favorites" : "Add to favorites"}
        onClick={() => void save({ isFavorite: !recipe.isFavorite })}
      >
        <Heart size={compact ? 16 : 20} fill={recipe.isFavorite ? "currentColor" : "none"} />
      </button>
    );
  }
  return (
    <div className="stars" role="group" aria-label="Rating">
      {[1, 2, 3, 4, 5].map((value) => (
        <button
          key={value}
          type="button"
          className={`icon-button star ${(recipe.rating ?? 0) >= value ? "on" : ""}`}
          aria-label={`${value} star${value === 1 ? "" : "s"}`}
          aria-pressed={recipe.rating === value}
          onClick={() => void save({ rating: recipe.rating === value ? null : value })}
        >
          <Star size={compact ? 14 : 20} fill={(recipe.rating ?? 0) >= value ? "currentColor" : "none"} />
        </button>
      ))}
    </div>
  );
}

/** Read-only version for list rows. */
export function RatingBadge({ recipe }: { recipe: RecipeView }) {
  const { ratingStyle } = usePrefs();
  if (ratingStyle === "favorites") return recipe.isFavorite ? <Heart size={13} fill="currentColor" className="accent" aria-label="Favorite" /> : null;
  return recipe.rating ? (
    <span className="accent rating-badge" aria-label={`${recipe.rating} stars`}>
      <Star size={13} fill="currentColor" /> {recipe.rating}
    </span>
  ) : null;
}
