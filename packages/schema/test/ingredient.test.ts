import { describe, expect, it } from "vitest";
import {
  buildCategoryTree,
  filterCategory,
  filterCollection,
  groceryParts,
  isIdea,
  ingredientAmount,
  ingredientHeading,
  ingredientName,
  ingredientPreparation,
  parseIngredient,
  standardIngredient,
  tagIsIn,
  type Recipe,
} from "../src/index.js";

describe("ingredient parsing", () => {
  // Same table as the Swift StandardsTests, so both implementations write the same text.
  const cases: [string, string, string | null, string, string][] = [
    ["2 Tablespoons butter", "2", "tbsp", "butter", "2 tbsp butter"],
    ["1 tablespoon olive oil", "1", "tbsp", "olive oil", "1 tbsp olive oil"],
    ["500g black beans, dried", "500", "g", "black beans, dried", "500 g black beans, dried"],
    ["1½ cup milk", "1 1/2", "cup", "milk", "1 1/2 cups milk"],
    ["½ cups flour", "1/2", "cup", "flour", "1/2 cup flour"],
    ["2 cloves of garlic, minced", "2", "clove", "garlic, minced", "2 cloves garlic, minced"],
    ["4 bell peppers", "4", null, "bell peppers", "4 bell peppers"],
    ["2-3 lbs. chicken thighs", "2-3", "lb", "chicken thighs", "2-3 lb chicken thighs"],
    ["8 fl oz water", "8", "fl oz", "water", "8 fl oz water"],
    ["Salt to taste", "", null, "Salt to taste", "Salt to taste"],
    ["2 cups", "", null, "2 cups", "2 cups"],
  ];

  it.each(cases)("parses %s", (input, quantity, unit, item, text) => {
    const parsed = parseIngredient(input);
    expect(parsed.quantity).toBe(quantity);
    expect(parsed.unit).toBe(unit);
    expect(parsed.item).toBe(item);
    expect(standardIngredient(input)).toBe(text);
    expect(standardIngredient(text)).toBe(text);
  });

  it("splits a line for display", () => {
    const garlic = parseIngredient("3 Cloves garlic, minced");
    expect(ingredientAmount(garlic)).toBe("3 cloves");
    expect(ingredientName(garlic)).toBe("garlic");
    expect(ingredientPreparation(garlic)).toBe("minced");
    const beans = parseIngredient("500g black beans, dried");
    expect(ingredientAmount(beans)).toBe("500 g");
    const salt = parseIngredient("Salt to taste");
    expect(ingredientAmount(salt)).toBe("");
    expect(ingredientName(salt)).toBe("Salt to taste");
  });

  it("strips decorative symbols", () => {
    expect(["🔹 1 lb boneless chicken", "• 2 tbsp. ghee", "▢ Kosher salt", "½ cup flour"].map(standardIngredient)).toEqual([
      "1 lb boneless chicken",
      "2 tbsp ghee",
      "Kosher salt",
      "1/2 cup flour",
    ]);
  });

  it("recognizes headings inside an ingredient list", () => {
    expect(ingredientHeading("DRESSING:")).toBe("Dressing");
    expect(ingredientHeading("For the sauce")).toBe("For the sauce");
    expect(ingredientHeading("1 cup flour")).toBeNull();
  });

  it("splits grocery lines", () => {
    expect(groceryParts("500g black beans")).toEqual({ quantity: "500g", name: "black beans" });
    expect(groceryParts("2 cups of flour")).toEqual({ quantity: "2 cups", name: "flour" });
    expect(groceryParts("Salt")).toEqual({ quantity: "", name: "Salt" });
  });
});

const recipe = (overrides: Partial<Recipe>): Recipe => ({
  id: "00000000-0000-0000-0000-000000000001",
  title: "R",
  summary: "",
  ingredients: [],
  ingredientSections: [],
  steps: [],
  stepTimestamps: [],
  stepImages: [],
  tags: [],
  notes: "",
  isFavorite: false,
  wantToCook: false,
  createdAt: "2026-01-01T00:00:00Z",
  updatedAt: "2026-01-01T00:00:00Z",
  ...overrides,
});

describe("categories and collections", () => {
  it("nests categories on a slash", () => {
    const tree = buildCategoryTree(["Dinner/Pasta", "Dinner/Soup", "dessert", "Dinner"]);
    expect(tree.map((node) => node.name)).toEqual(["Dessert", "Dinner"].map((name) => tree.find((n) => n.name.toLowerCase() === name.toLowerCase())!.name));
    expect(tree.find((node) => node.name === "Dinner")!.children.map((node) => node.path)).toEqual(["Dinner/Pasta", "Dinner/Soup"]);
    expect(tagIsIn("Dinner/Pasta", "dinner")).toBe(true);
    expect(tagIsIn("Dinner", "Dinner/Pasta")).toBe(false);
  });

  it("filters like the app's collections", () => {
    const all = [
      recipe({ id: "00000000-0000-0000-0000-00000000000a", title: "A", rating: 5, createdAt: "2026-01-02T00:00:00Z" }),
      recipe({ id: "00000000-0000-0000-0000-00000000000b", title: "B", rating: 4, createdAt: "2026-01-03T00:00:00Z" }),
      recipe({ id: "00000000-0000-0000-0000-00000000000c", title: "C", rating: 3, tags: ["Dinner/Pasta"] }),
      recipe({ id: "00000000-0000-0000-0000-00000000000d", title: "Q1", wantToCook: true, queuedAt: "2026-02-02T00:00:00Z" }),
      recipe({ id: "00000000-0000-0000-0000-00000000000e", title: "Q2", wantToCook: true, queuedAt: "2026-02-01T00:00:00Z" }),
    ];
    expect(filterCollection(all, "top-rated").map((r) => r.title)).toEqual(["A", "B"]);
    expect(filterCollection(all, "up-next").map((r) => r.title)).toEqual(["Q2", "Q1"]);
    expect(filterCollection(all, "uncategorized").map((r) => r.title)).not.toContain("C");
    expect(filterCategory(all, "dinner").map((r) => r.title)).toEqual(["C"]);
  });

  it("treats a recipe with nothing to cook as an idea", () => {
    expect(isIdea(recipe({ title: "Spaghetti", notes: "Use the good pasta" }))).toBe(true);
    expect(isIdea(recipe({ title: "Spaghetti", ingredients: ["1 lb spaghetti"] }))).toBe(false);
    expect(isIdea(recipe({ title: "Spaghetti", steps: ["Boil the pasta."] }))).toBe(false);
  });
});
