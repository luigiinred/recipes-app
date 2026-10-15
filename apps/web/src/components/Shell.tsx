import { buildCategoryTree, collectionTitles, filterCollection, type CategoryNode, type CollectionId } from "@recipes/schema/lib";
import {
  BookOpen,
  CalendarDays,
  Clock,
  FolderOpen,
  Heart,
  ListOrdered,
  Settings as SettingsIcon,
  ShoppingBasket,
  Star,
  Tag,
  UtensilsCrossed,
  type LucideIcon,
} from "lucide-react";
import { useEffect, useMemo } from "react";
import { CookPage } from "../pages/Cook.js";
import { EditorPage } from "../pages/Editor.js";
import { GroceriesPage } from "../pages/Groceries.js";
import { ImportPage } from "../pages/Import.js";
import { PlanPage } from "../pages/Plan.js";
import { RecipesPage } from "../pages/Recipes.js";
import { SettingsPage } from "../pages/Settings.js";
import { useLibrary } from "../lib/library.js";
import { Link, navigate, recipesUrl, useLocation } from "../lib/router.js";
import { usePrefs } from "../lib/prefs.js";

const COLLECTION_ICONS: Record<CollectionId, LucideIcon> = {
  all: BookOpen,
  recent: Clock,
  "up-next": ListOrdered,
  favorites: Heart,
  "top-rated": Star,
  uncategorized: FolderOpen,
};

export function Shell({ version, onSignedOut }: { version: string; onSignedOut: () => void }) {
  const { path } = useLocation();
  useEffect(() => {
    if (path === "/") navigate("/recipes", { replace: true });
  }, [path]);

  const parts = path.split("/").filter(Boolean);
  // Cook mode takes the whole screen.
  if (parts[0] === "recipes" && parts[2] === "cook") return <CookPage id={parts[1]!} />;

  return (
    <div className="shell">
      <Sidebar />
      <main className="main">
        <Routes parts={parts} version={version} onSignedOut={onSignedOut} />
      </main>
      <TabBar />
    </div>
  );
}

function Routes({ parts, version, onSignedOut }: { parts: string[]; version: string; onSignedOut: () => void }) {
  switch (parts[0]) {
    case "recipes":
      return parts[2] === "edit" ? <EditorPage key={parts[1]} id={parts[1]} /> : <RecipesPage selectedId={parts[1]} />;
    case "new":
      return <EditorPage key="new" />;
    case "import":
      return <ImportPage />;
    case "plan":
      return <PlanPage />;
    case "groceries":
      return <GroceriesPage />;
    case "settings":
      return <SettingsPage version={version} onSignedOut={onSignedOut} />;
    default:
      return (
        <div className="page">
          <p className="muted">There's nothing at this address. <Link to="/recipes">Back to your recipes</Link></p>
        </div>
      );
  }
}

function Sidebar() {
  const { recipes, groceries } = useLibrary();
  const prefs = usePrefs();
  const { path, search } = useLocation();
  const tree = useMemo(() => buildCategoryTree(recipes.flatMap((recipe) => recipe.tags)), [recipes]);
  const onRecipes = path.startsWith("/recipes");
  const activeCollection = (search.get("collection") ?? (search.get("tag") ? "" : "all")) as CollectionId | "";
  const activeTag = search.get("tag");
  const open = groceries.filter((item) => !item.isChecked).length;

  const collections: CollectionId[] = ["all", "recent", "up-next", prefs.ratingStyle === "stars" ? "top-rated" : "favorites", "uncategorized"];

  return (
    <nav className="sidebar" aria-label="Library">
      <Link to="/recipes" className="brand serif">
        <UtensilsCrossed size={20} /> Recipes
      </Link>
      <ul className="nav-list">
        {collections.map((id) => {
          const Icon = COLLECTION_ICONS[id];
          return (
            <li key={id}>
              <Link to={recipesUrl({ collection: id })} className={onRecipes && activeCollection === id ? "active" : ""}>
                <Icon size={17} /> {collectionTitles[id]}
                <span className="count">{id === "all" || id === "recent" ? "" : filterCollection(recipes, id).length || ""}</span>
              </Link>
            </li>
          );
        })}
      </ul>
      {tree.length > 0 && (
        <>
          <h2 className="nav-heading">Categories</h2>
          <ul className="nav-list">
            {tree.map((node) => (
              <CategoryItem key={node.path} node={node} active={onRecipes ? activeTag : null} />
            ))}
          </ul>
        </>
      )}
      <h2 className="nav-heading">Plan</h2>
      <ul className="nav-list">
        <li>
          <Link to="/plan" className={path === "/plan" ? "active" : ""}>
            <CalendarDays size={17} /> Plan
          </Link>
        </li>
        <li>
          <Link to="/groceries" className={path === "/groceries" ? "active" : ""}>
            <ShoppingBasket size={17} /> Groceries<span className="count">{open || ""}</span>
          </Link>
        </li>
      </ul>
      <div className="sidebar-foot">
        <Link to="/settings" className={path === "/settings" ? "active" : ""}>
          <SettingsIcon size={17} /> Settings
        </Link>
      </div>
    </nav>
  );
}

function CategoryItem({ node, active }: { node: CategoryNode; active: string | null }) {
  const isActive = active?.toLowerCase() === node.path.toLowerCase();
  const containsActive = !!active && active.toLowerCase().startsWith(node.path.toLowerCase() + "/");
  return (
    <li>
      <Link to={recipesUrl({ tag: node.path })} className={isActive ? "active" : ""}>
        <Tag size={15} /> {node.name}
      </Link>
      {node.children.length > 0 && (isActive || containsActive) && (
        <ul className="nav-list nested">
          {node.children.map((child) => (
            <CategoryItem key={child.path} node={child} active={active} />
          ))}
        </ul>
      )}
    </li>
  );
}

function TabBar() {
  const { path } = useLocation();
  const tabs = [
    { to: "/recipes", label: "Recipes", Icon: BookOpen, match: "/recipes" },
    { to: "/plan", label: "Plan", Icon: CalendarDays, match: "/plan" },
    { to: "/groceries", label: "Groceries", Icon: ShoppingBasket, match: "/groceries" },
    { to: "/settings", label: "Settings", Icon: SettingsIcon, match: "/settings" },
  ];
  return (
    <nav className="tabbar" aria-label="Main">
      {tabs.map(({ to, label, Icon, match }) => (
        <Link key={to} to={to} className={path.startsWith(match) || (match === "/recipes" && (path === "/new" || path === "/import")) ? "active" : ""}>
          <Icon size={22} />
          <span>{label}</span>
        </Link>
      ))}
    </nav>
  );
}
