const MAIN: Record<string, string[]> = {
  Beef: ["beef", "steak", "brisket", "sirloin", "ribeye", "short rib", "short ribs", "meatball", "meatballs", "burger"],
  Pork: ["pork", "bacon", "ham", "sausage", "sausages", "prosciutto", "pancetta", "chorizo", "carnitas"],
  Chicken: ["chicken", "drumstick", "drumsticks"],
  Turkey: ["turkey"],
  Lamb: ["lamb", "mutton"],
  Fish: ["fish", "salmon", "cod", "tuna", "trout", "tilapia", "halibut", "haddock", "mackerel", "sardine", "sardines", "anchovy", "anchovies", "snapper", "bass"],
  Seafood: ["shrimp", "prawn", "prawns", "crab", "lobster", "scallop", "scallops", "mussel", "mussels", "clam", "clams", "squid", "calamari", "oyster", "oysters"],
  Eggs: ["egg", "eggs", "omelet", "omelette", "frittata", "shakshuka", "quiche"],
  Pasta: ["pasta", "spaghetti", "penne", "linguine", "fettuccine", "macaroni", "lasagna", "lasagne", "rigatoni", "noodle", "noodles", "ramen", "gnocchi", "orzo"],
  Rice: ["rice", "risotto", "paella", "biryani", "pilaf"],
  Beans: ["beans", "bean", "lentil", "lentils", "chickpea", "chickpeas", "dal", "dahl", "hummus"],
  Tofu: ["tofu", "tempeh", "seitan"],
};

const COURSE: Record<string, string[]> = {
  Breakfast: ["breakfast", "brunch", "pancake", "pancakes", "waffle", "waffles", "granola", "oatmeal", "porridge", "french toast", "muffin", "muffins"],
  Dessert: ["dessert", "desserts", "cake", "cookie", "cookies", "brownie", "brownies", "pie", "pudding", "ice cream", "cheesecake", "tart", "fudge", "mousse"],
  Soup: ["soup", "stew", "chowder", "bisque", "chili"],
  Salad: ["salad", "slaw"],
  Appetizer: ["appetizer", "appetizers", "starter", "starters", "dip", "hors d'oeuvre"],
  Side: ["side", "side dish"],
  Snack: ["snack", "snacks"],
  Drink: ["drink", "drinks", "cocktail", "smoothie", "beverage", "lemonade"],
  Lunch: ["lunch", "sandwich", "wrap"],
  Dinner: ["dinner", "main", "main course", "main dish", "entree", "supper"],
};

const MEATS = new Set(["Beef", "Pork", "Chicken", "Turkey", "Lamb", "Fish", "Seafood"]);
const STOCKS = ["broth", "stock", "bouillon", "lard", "gelatin", "anchovy", "anchovies", "fish sauce", "worcestershire"];
const IMPORT_LIMIT = 4;

const words = (text: string): string[] => text.toLowerCase().split(/[^\p{L}']+/u).filter(Boolean);

function hasPhrase(list: string[], keyword: string): boolean {
  const parts = keyword.split(" ");
  if (parts.length === 1) return list.includes(parts[0]!);
  return list.some((_, i) => parts.every((part, offset) => list[i + offset] === part));
}

/** The tag a page's own category or keyword stands for, such as "Main Course" → Dinner. */
function canonical(term: string): string | null {
  const key = term.trim().toLowerCase();
  if (!key) return null;
  const vocabulary = [...Object.keys(MAIN), "Vegetarian", "Vegan", ...Object.keys(COURSE)];
  const exact = vocabulary.find((tag) => tag.toLowerCase() === key) ?? (key.endsWith("s") ? vocabulary.find((tag) => tag.toLowerCase() === key.slice(0, -1)) : undefined);
  if (exact) return exact;
  for (const [tag, list] of Object.entries(COURSE)) if (list.includes(key)) return tag;
  for (const [tag, list] of Object.entries(MAIN)) if (list.includes(key)) return tag;
  return key === "veggie" || key === "vegetables" ? "Vegetarian" : null;
}

/** Generic tags for an imported recipe: its main ingredient and course (at most four). */
export function suggestTags(title: string, ingredients: string[], sourceTerms: string[] = []): string[] {
  const titleWords = words(title);
  const leading = ingredients.slice(0, 4).map((line) => line.toLowerCase());
  const isStock = (item: string) => STOCKS.some((stock) => item.includes(stock));

  let main: string[] = [];
  for (const [tag, list] of Object.entries(MAIN)) {
    const inTitle = list.some((word) => hasPhrase(titleWords, word));
    const inLeading = tag !== "Eggs" && leading.some((item) => list.some((word) => hasPhrase(words(item), word)) && !isStock(item));
    if (inTitle || inLeading) main.push(tag);
  }
  if (main.some((tag) => MEATS.has(tag))) main = main.filter((tag) => !["Pasta", "Rice", "Eggs", "Beans"].includes(tag));
  const tags = main.slice(0, 2);

  let course: string | undefined;
  for (const term of sourceTerms) {
    const tag = canonical(term);
    if (tag && tag in COURSE) {
      course = tag;
      break;
    }
  }
  if (!course) course = Object.keys(COURSE).sort().find((tag) => COURSE[tag]!.some((word) => hasPhrase(titleWords, word)));
  for (const term of sourceTerms) {
    const tag = canonical(term);
    if (tag && !(tag in COURSE) && !tags.includes(tag) && tag in MAIN) tags.push(tag);
  }
  if (course) tags.push(course);
  return [...new Set(tags)].slice(0, IMPORT_LIMIT);
}
