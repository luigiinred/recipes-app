import type { RecipeInput } from "@recipes/schema";
import { suggestTags } from "./tags.js";

type Json = unknown;
type Obj = Record<string, unknown>;

const NAMED_ENTITIES: Record<string, string> = {
  amp: "&", quot: '"', apos: "'", lt: "<", gt: ">", nbsp: " ", ndash: "–", mdash: "—", lsquo: "‘", rsquo: "’",
  ldquo: "“", rdquo: "”", hellip: "…", deg: "°", frac12: "½", frac14: "¼", frac34: "¾", eacute: "é", egrave: "è",
};

export function decodeEntities(text: string): string {
  return text.replace(/&(?:#(x?)([0-9a-f]+)|([a-z0-9]+));/gi, (whole, hex: string, digits: string, name: string) => {
    if (digits) {
      const code = Number.parseInt(digits, hex ? 16 : 10);
      return Number.isInteger(code) && code > 0 && code <= 0x10ffff ? String.fromCodePoint(code) : "";
    }
    return NAMED_ENTITIES[name.toLowerCase()] ?? whole;
  });
}

/** Removes `<...>` runs in one pass. (A regex for this goes quadratic on input with many `<` and no `>`.) */
function stripTags(text: string): string {
  let out = "";
  let from = 0;
  let close = -1;
  for (;;) {
    const open = text.indexOf("<", from);
    if (open < 0) return out + text.slice(from);
    if (close < open) close = text.indexOf(">", open);
    if (close < 0) return out + text.slice(from);
    out += text.slice(from, open);
    from = close + 1;
  }
}

export function clean(text: string): string {
  return decodeEntities(stripTags(text)).trim();
}

/** A page or video title without the site name tacked on: "Best Cookies | Preppy Kitchen", "Cookies Recipe by Tasty". */
export function importedTitle(text: string): string {
  let title = text.split(/\s+/).filter(Boolean).join(" ");
  const bar = title.indexOf(" | ");
  if (bar >= 0) title = title.slice(0, bar);
  title = title.replace(/ Recipe by [^|]+$/i, "");
  return title || text;
}

const MAX_TAG_LENGTH = 2000;

/** Contents of every `<script type="application/ld+json">`, found with forward-only scans so hostile pages can't make it slow. */
export function jsonLdBlocks(html: string): string[] {
  const lower = html.toLowerCase();
  const blocks: string[] = [];
  let from = 0;
  for (;;) {
    const open = lower.indexOf("<script", from);
    if (open < 0) return blocks;
    const tagEnd = lower.indexOf(">", open);
    if (tagEnd < 0) return blocks;
    from = open + "<script".length;
    if (tagEnd - open > MAX_TAG_LENGTH || !/type\s*=\s*["']application\/ld\+json["']/.test(lower.slice(open, tagEnd))) continue;
    const close = lower.indexOf("</script", tagEnd);
    if (close < 0) return blocks;
    blocks.push(
      html
        .slice(tagEnd + 1, close)
        .replace(/\/\/\s*<!\[CDATA\[|\/\/\s*\]\]>|<!\[CDATA\[|\]\]>/g, "")
        .trim(),
    );
    from = close;
  }
}

const isObject = (value: Json): value is Obj => typeof value === "object" && value !== null && !Array.isArray(value);

function isRecipeType(type: Json): boolean {
  if (typeof type === "string") return type === "Recipe";
  return Array.isArray(type) && type.includes("Recipe");
}

function findRecipe(json: Json): Obj | null {
  if (Array.isArray(json)) {
    for (const item of json) {
      const found = findRecipe(item);
      if (found) return found;
    }
    return null;
  }
  if (!isObject(json)) return null;
  if (isRecipeType(json["@type"])) return json;
  return json["@graph"] ? findRecipe(json["@graph"]) : null;
}

function strings(value: Json): string[] {
  if (typeof value === "string") return [clean(value)].filter(Boolean);
  if (typeof value === "number") return [String(value)];
  if (Array.isArray(value)) return value.flatMap(strings);
  if (isObject(value)) {
    return Object.entries(value)
      .sort(([a], [b]) => (Number(a) || Infinity) - (Number(b) || Infinity))
      .flatMap(([, member]) => strings(member));
  }
  return [];
}

const text = (value: Json): string | undefined => strings(value)[0];

function instructions(value: Json): string[] {
  if (typeof value === "string") return value.split(/\r?\n/).map(clean).filter(Boolean);
  if (Array.isArray(value)) return value.flatMap(instructions);
  if (isObject(value)) {
    if (value.itemListElement) return instructions(value.itemListElement);
    const step = text(value.text) ?? text(value.name);
    if (step) return [step];
    return Object.entries(value)
      .sort(([a], [b]) => (Number(a) || Infinity) - (Number(b) || Infinity))
      .flatMap(([, member]) => instructions(member));
  }
  return [];
}

function imageLink(value: Json): string | undefined {
  if (typeof value === "string") return value;
  if (Array.isArray(value)) return value.map(imageLink).find(Boolean);
  if (isObject(value)) return imageLink(value.url ?? value.contentUrl);
  return undefined;
}

/** ISO 8601 duration such as PT1H30M, in minutes. */
export function minutes(value: Json): number | undefined {
  if (typeof value !== "string") return undefined;
  const match = /^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?)?$/.exec(value);
  if (!match) return undefined;
  const total = Number(match[1] ?? 0) * 1440 + Number(match[2] ?? 0) * 60 + Number(match[3] ?? 0);
  return total > 0 ? total : undefined;
}

function servingsFrom(value: Json): number | undefined {
  const digits = /\d+/.exec(strings(value)[0] ?? "")?.[0];
  return digits ? Number(digits) : undefined;
}

export function openGraphImage(html: string): string | undefined {
  const lower = html.toLowerCase();
  let from = 0;
  let close = -1;
  for (;;) {
    const open = lower.indexOf("<meta", from);
    if (open < 0) return undefined;
    from = open + "<meta".length;
    if (close < open) close = lower.indexOf(">", open);
    if (close < 0) return undefined;
    if (close - open > MAX_TAG_LENGTH) continue;
    const tag = html.slice(open, close + 1);
    if (!/(?:property|name)\s*=\s*["']og:image(?::secure_url)?["']/i.test(tag)) continue;
    const content = /content\s*=\s*["']([^"']+)["']/i.exec(tag)?.[1];
    if (content) return clean(content);
  }
}

export interface ParsedPage {
  draft: RecipeInput;
  /** Absolute address of the cover photo, if the page names one. */
  imageURL?: string;
}

/** The first schema.org Recipe on the page, or null when it has none. */
export function parseRecipePage(html: string, pageURL: URL): ParsedPage | null {
  for (const block of jsonLdBlocks(html)) {
    let json: Json;
    try {
      json = JSON.parse(block);
    } catch {
      continue;
    }
    const object = findRecipe(json);
    const rawTitle = object ? text(object.name) : undefined;
    if (!object || !rawTitle) continue;

    const title = importedTitle(rawTitle);
    const ingredients = strings(object.recipeIngredient ?? object.ingredients);
    const keywords = (text(object.keywords) ?? "").split(",").map((word) => word.trim());
    const found = imageLink(object.image) ?? openGraphImage(html);
    let imageURL: string | undefined;
    if (found) {
      try {
        imageURL = new URL(found, pageURL).toString();
      } catch {
        imageURL = undefined;
      }
    }
    return {
      imageURL,
      draft: {
        title,
        summary: text(object.description) ?? "",
        servings: servingsFrom(object.recipeYield),
        prepMinutes: minutes(object.prepTime),
        cookMinutes: minutes(object.cookTime),
        ingredients,
        steps: instructions(object.recipeInstructions),
        tags: suggestTags(title, ingredients, [...strings(object.recipeCategory), ...keywords]),
        sourceURL: pageURL.toString(),
        imageURL,
      } as RecipeInput,
    };
  }
  return null;
}
