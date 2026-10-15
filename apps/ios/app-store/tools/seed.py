#!/usr/bin/env python3
"""Fills a library folder with the demo recipes, photos, week plan and groceries used for the screenshots.

Usage: seed.py <library-dir>   (needs `swift build -c release --product recipes` in apps/ios)
"""
import datetime, json, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
CLI = os.path.join(HERE, "../../.build/release/recipes")
lib = os.path.abspath(sys.argv[1])
shutil.rmtree(lib, ignore_errors=True)
os.makedirs(lib)


def run(*args):
    return subprocess.run([CLI, *args, "--dir", lib], check=True, capture_output=True, text=True).stdout


recipes = json.load(open(f"{HERE}/seed/recipes.json"))
# Added oldest first, so the first recipes in the file are the newest in "Most Recent".
for recipe in reversed(recipes):
    slug = recipe.pop("slug")
    path = f"{lib}/.{slug}.json"
    json.dump(recipe, open(path, "w"))
    run("add", "--from", path, "--image", f"{HERE}/seed/photos/{slug}.jpg")
    os.remove(path)

for title in ["Leftovers", "Sandwiches", "Pizza night"]:
    run("add", "--title", title)

today = datetime.date.today()
sunday = today - datetime.timedelta(days=(today.weekday() + 1) % 7)
plan = [(0, "Buckwheat Pancakes", "breakfast"), (0, "Herby Lentil Salad", "lunch"), (0, "Thai Red Curry", "dinner"),
        (1, "Fig and Ricotta Toast", "breakfast"), (1, "Mushroom Fried Rice", "dinner"),
        (2, "Carrot and Egg Salad Bowl", "lunch"), (2, "Slow-Braised Beef", "dinner"),
        (3, "Shakshuka", "breakfast"), (3, "Pappardelle with Mushrooms and Sage", "dinner"),
        (4, "Spinach and Gruyère Quiche", "dinner"), (6, "Pesto Pasta Salad", "lunch"), (6, "Garlic White Wine Clams", "dinner"),
        (1, "Leftovers", "lunch"), (3, "Sandwiches", "lunch"), (5, "Pizza night", "dinner")]
for offset, title, meal in plan:
    run("plan", "add", title, "--date", str(sunday + datetime.timedelta(days=offset)), "--meal", meal)

items = ["12 oz Farfalle", "1 cup Basil pesto", "1 pint Cherry tomatoes", "2 cups Arugula", "1 Lemon", "Parmesan", "6 Eggs",
         "1 Sourdough loaf", "2 cups Milk", "1 lb Mushrooms", "Olive oil"]
run("groceries", "add", *items)
checked = {"Eggs", "Milk", "Olive oil"}
for entry in json.loads(run("groceries", "list", "--json")):
    if entry.get("name", entry.get("title", "")) in checked or entry.get("text", "") in checked:
        run("groceries", "check", entry["id"][:8])
print(lib)
