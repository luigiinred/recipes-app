/** Categories are tags; a "/" nests one under another, so "Dinner/Pasta" is Pasta inside Dinner. */
export interface CategoryNode {
  path: string;
  name: string;
  children: CategoryNode[];
}

const collator = new Intl.Collator(undefined, { sensitivity: "base", numeric: true });
const same = (a: string, b: string): boolean => collator.compare(a, b) === 0;

export function categoryComponents(tag: string): string[] {
  return tag
    .split("/")
    .map((part) => part.trim())
    .filter(Boolean);
}

export function normalizeCategory(tag: string): string {
  return categoryComponents(tag).join("/");
}

export function categoryDisplayName(tag: string): string {
  return categoryComponents(tag).join(" › ");
}

export function buildCategoryTree(tags: string[]): CategoryNode[] {
  const paths = tags.map(categoryComponents).filter((path) => path.length > 0);
  const nodes = (prefix: string[]): CategoryNode[] => {
    const seen: string[] = [];
    for (const path of paths) {
      if (path.length <= prefix.length || !prefix.every((part, i) => same(part, path[i]!))) continue;
      const next = path[prefix.length]!;
      if (!seen.some((name) => same(name, next))) seen.push(next);
    }
    return seen
      .sort((a, b) => collator.compare(a, b))
      .map((name) => {
        const childPrefix = [...prefix, name];
        return { path: childPrefix.join("/"), name, children: nodes(childPrefix) };
      });
  };
  return nodes([]);
}

/** True when `tag` is `category` or sits anywhere beneath it. */
export function tagIsIn(tag: string, category: string): boolean {
  const tagParts = categoryComponents(tag);
  const categoryParts = categoryComponents(category);
  if (categoryParts.length === 0 || tagParts.length < categoryParts.length) return false;
  return categoryParts.every((part, i) => same(part, tagParts[i]!));
}
