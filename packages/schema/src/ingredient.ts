/** Ingredient lines in the app's one standard form: "1 1/2 cups flour", "2 cloves garlic, minced". */

interface UnitSpec {
  singular: string;
  plural: string;
  aliases: string[];
}

const UNITS: UnitSpec[] = [
  { singular: "tsp", plural: "tsp", aliases: ["tsp", "tsps", "teaspoon", "teaspoons"] },
  { singular: "tbsp", plural: "tbsp", aliases: ["tbsp", "tbsps", "tbs", "tablespoon", "tablespoons"] },
  { singular: "cup", plural: "cups", aliases: ["cup", "cups"] },
  { singular: "fl oz", plural: "fl oz", aliases: ["floz", "fl.oz", "fl.oz."] },
  { singular: "pint", plural: "pints", aliases: ["pt", "pint", "pints"] },
  { singular: "quart", plural: "quarts", aliases: ["qt", "qts", "quart", "quarts"] },
  { singular: "gallon", plural: "gallons", aliases: ["gal", "gallon", "gallons"] },
  { singular: "ml", plural: "ml", aliases: ["ml", "milliliter", "milliliters", "millilitre", "millilitres"] },
  { singular: "cl", plural: "cl", aliases: ["cl"] },
  { singular: "dl", plural: "dl", aliases: ["dl"] },
  { singular: "l", plural: "l", aliases: ["l", "liter", "liters", "litre", "litres"] },
  { singular: "mg", plural: "mg", aliases: ["mg"] },
  { singular: "g", plural: "g", aliases: ["g", "gram", "grams"] },
  { singular: "kg", plural: "kg", aliases: ["kg", "kilogram", "kilograms"] },
  { singular: "oz", plural: "oz", aliases: ["oz", "ounce", "ounces"] },
  { singular: "lb", plural: "lb", aliases: ["lb", "lbs", "pound", "pounds"] },
  { singular: "pinch", plural: "pinches", aliases: ["pinch", "pinches"] },
  { singular: "dash", plural: "dashes", aliases: ["dash", "dashes"] },
  { singular: "clove", plural: "cloves", aliases: ["clove", "cloves"] },
  { singular: "can", plural: "cans", aliases: ["can", "cans"] },
  { singular: "package", plural: "packages", aliases: ["package", "packages", "pkg", "pkgs"] },
  { singular: "jar", plural: "jars", aliases: ["jar", "jars"] },
  { singular: "bunch", plural: "bunches", aliases: ["bunch", "bunches"] },
  { singular: "sprig", plural: "sprigs", aliases: ["sprig", "sprigs"] },
  { singular: "stalk", plural: "stalks", aliases: ["stalk", "stalks"] },
  { singular: "head", plural: "heads", aliases: ["head", "heads"] },
  { singular: "slice", plural: "slices", aliases: ["slice", "slices"] },
  { singular: "stick", plural: "sticks", aliases: ["stick", "sticks"] },
  { singular: "handful", plural: "handfuls", aliases: ["handful", "handfuls"] },
];

const ALIASES = new Map<string, UnitSpec>();
for (const unit of UNITS) for (const alias of unit.aliases) ALIASES.set(alias, unit);

const FLUID_OUNCE = ALIASES.get("floz")!;

const unitFor = (alias: string): UnitSpec | undefined =>
  ALIASES.get(alias.toLowerCase().replace(/^\p{P}+|\p{P}+$/gu, ""));

const VULGAR: Record<string, string> = {
  "¼": "1/4", "½": "1/2", "¾": "3/4", "⅓": "1/3", "⅔": "2/3", "⅛": "1/8", "⅜": "3/8", "⅝": "5/8", "⅞": "7/8",
};
const NUMBER_CHARACTERS = new Set("0123456789./-–,");

const isNumber = (char: string): boolean => /\p{N}/u.test(char);
const isNumeric = (token: string): boolean => token !== "" && (isNumber(token[0]!) || token[0]! in VULGAR);
const words = (text: string): string[] => text.split(/\s+/).filter(Boolean);

function splitNumber(token: string): { number: string; suffix: string } {
  const chars = [...token];
  let index = 0;
  while (index < chars.length) {
    const char = chars[index]!;
    if (!(isNumber(char) || char in VULGAR || NUMBER_CHARACTERS.has(char))) break;
    index += 1;
  }
  return { number: chars.slice(0, index).join(""), suffix: chars.slice(index).join("") };
}

/** "½" and "1½" become "1/2" and "1 1/2"; surrounding spaces collapse. */
export function normalizeQuantity(quantity: string): string {
  let result = "";
  for (const char of quantity) {
    if (char in VULGAR) {
      if (result && isNumber(result.at(-1)!)) result += " ";
      result += VULGAR[char];
    } else {
      result += char;
    }
  }
  return words(result).join(" ");
}

/** Numeric value of "1 1/2", "0.5" or "2-3" (a range reads as its upper end); null when it isn't a number. */
export function quantityValue(quantity: string): number | null {
  const upper = quantity.split(/[-–]/).filter(Boolean).at(-1);
  if (!upper) return null;
  const parts = words(upper);
  if (parts.length === 0) return null;
  let total = 0;
  for (const part of parts) {
    const pieces = part.split("/").map((piece) => (piece.trim() === "" ? NaN : Number(piece)));
    if (pieces.length === 2 && !Number.isNaN(pieces[0]!) && !Number.isNaN(pieces[1]!) && pieces[1] !== 0) total += pieces[0]! / pieces[1]!;
    else if (pieces.length === 1 && !Number.isNaN(pieces[0]!)) total += pieces[0]!;
    else return null;
  }
  return total;
}

export interface Ingredient {
  quantity: string;
  unit: string | null;
  item: string;
}

/** Drops the bullets, diamonds, checkboxes and emoji some sites put in front of an ingredient. */
function stripDecoration(text: string): string {
  const chars = [...text];
  let index = 0;
  while (index < chars.length) {
    const char = chars[index]!;
    if (/\p{L}/u.test(char) || isNumber(char) || char === "(") break;
    if (char === "." && chars[index + 1] && isNumber(chars[index + 1]!)) break;
    index += 1;
  }
  return chars.slice(index).join("");
}

export function parseIngredient(text: string): Ingredient {
  const tokens = words(stripDecoration(text));
  const original = tokens.join(" ");
  const quantityTokens: string[] = [];
  let unit: UnitSpec | undefined;

  while (!unit && tokens.length > 0 && isNumeric(tokens[0]!)) {
    const token = tokens.shift()!;
    const { number, suffix } = splitNumber(token);
    if (suffix === "") {
      quantityTokens.push(number);
    } else {
      const attached = unitFor(suffix);
      if (attached) {
        quantityTokens.push(number);
        unit = attached;
      } else {
        quantityTokens.push(token);
      }
    }
  }
  if (quantityTokens.length > 0 && !unit && tokens.length > 0) {
    const first = tokens[0]!.toLowerCase();
    if ((first === "fl" || first === "fl.") && tokens.length > 1 && ["oz", "oz."].includes(tokens[1]!.toLowerCase())) {
      unit = FLUID_OUNCE;
      tokens.splice(0, 2);
    } else {
      const spoken = unitFor(tokens[0]!);
      if (spoken) {
        unit = spoken;
        tokens.shift();
      }
    }
  }
  if (unit && tokens[0]?.toLowerCase() === "of") tokens.shift();

  const item = tokens.join(" ");
  if (quantityTokens.length === 0 || item === "") return { quantity: "", unit: null, item: original };
  return { quantity: normalizeQuantity(quantityTokens.join(" ")), unit: unit?.singular ?? null, item };
}

function unitLabel(unit: string, quantity: string): string {
  const spec = UNITS.find((candidate) => candidate.singular === unit);
  if (!spec) return unit;
  const value = quantityValue(quantity);
  return value !== null && value <= 1 ? spec.singular : spec.plural;
}

/** The quantity and unit together, such as "1 1/2 cups"; empty for items without one. */
export function ingredientAmount(ingredient: Ingredient): string {
  const amount = normalizeQuantity(ingredient.quantity);
  if (!amount) return "";
  return ingredient.unit ? `${amount} ${unitLabel(ingredient.unit, amount)}` : amount;
}

/** The item without its preparation: "garlic" for "garlic, minced". */
export function ingredientName(ingredient: Ingredient): string {
  return ingredient.item.split(",", 1)[0]!.trim();
}

/** How the item is prepared: "minced" for "garlic, minced". */
export function ingredientPreparation(ingredient: Ingredient): string {
  const comma = ingredient.item.indexOf(",");
  return comma >= 0 ? ingredient.item.slice(comma + 1).trim() : "";
}

/** The standard written form. A unit without a quantity reads as one. */
export function ingredientText(ingredient: Ingredient): string {
  const name = words(ingredient.item).join(" ");
  let amount = normalizeQuantity(ingredient.quantity);
  if (!amount && ingredient.unit && name) amount = "1";
  const parts: string[] = [];
  if (amount) parts.push(amount);
  if (ingredient.unit && amount) parts.push(unitLabel(ingredient.unit, amount));
  if (name) parts.push(name);
  return parts.join(" ");
}

export function standardIngredient(text: string): string {
  return ingredientText(parseIngredient(text));
}

/** "DRESSING:" or "For the sauce" on a line of its own inside an ingredient list. */
export function ingredientHeading(text: string): string | null {
  const trimmed = words(text).join(" ");
  if (!trimmed || trimmed.length > 40 || /\p{N}/u.test(trimmed)) return null;
  const name = trimmed.replace(/^[:\s]+|[:\s]+$/g, "");
  if (!name || !(trimmed.endsWith(":") || name.toLowerCase().startsWith("for the "))) return null;
  const shouting = name === name.toUpperCase() && /\p{L}/u.test(name);
  return shouting ? name.toLowerCase().replace(/(^|\s)\p{L}/gu, (match) => match.toUpperCase()) : name;
}

/** Splits a recipe line into what a shopping list shows: "500g black beans" → quantity "500g", name "black beans". */
export function groceryParts(text: string): { quantity: string; name: string } {
  const trimmed = text.trim();
  const tokens = words(trimmed);
  let index = 0;
  while (index < tokens.length && isNumeric(tokens[index]!)) index += 1;
  if (index === 0) return { quantity: "", name: trimmed };
  if (index < tokens.length && unitFor(tokens[index]!)) index += 1;
  const quantity = tokens.slice(0, index).join(" ");
  if (index < tokens.length && tokens[index]!.toLowerCase() === "of") index += 1;
  const name = tokens.slice(index).join(" ");
  return name ? { quantity, name } : { quantity: "", name: trimmed };
}
