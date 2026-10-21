import { ingredientHeading, isoDate, normalizeCategory, standardIngredient, type Recipe, type recipeInputSchema } from "@recipes/schema";
import type { z } from "zod";

const collapse = (text: string): string => text.split(/\s+/).filter(Boolean).join(" ");

const STEP_PREFIX = /^\s*(?:(?:step\s*)?\d+\s*[.):\-–]+\s*|[-–•*]\s+)/i;

function cleanStep(text: string): string {
  let step = collapse(text).replace(STEP_PREFIX, "");
  if (!step) return "";
  const first = step[0]!;
  if (first !== first.toUpperCase()) step = first.toUpperCase() + step.slice(1);
  return /[\p{L}\p{N})]$/u.test(step) ? `${step}.` : step;
}

/** Only web links are kept: these values end up in `href` and `src` attributes. */
export function webURL(value: string | null | undefined): string | undefined {
  const trimmed = value?.trim();
  if (!trimmed) return undefined;
  try {
    const url = new URL(trimmed);
    return url.protocol === "http:" || url.protocol === "https:" ? trimmed : undefined;
  } catch {
    return undefined;
  }
}

const positive = (value: number | null | undefined): number | undefined => (value != null && value > 0 ? value : undefined);

/**
 * Puts a recipe in the shape the apps expect: tidy text, steps and their timestamps/photos kept parallel,
 * section headings pointing at real ingredients. Applying it twice changes nothing.
 */
export function normalizeRecipe(
  input: z.output<typeof recipeInputSchema>,
  id: string,
  existing: Recipe | null,
  now: Date,
): Recipe {
  const ingredients: string[] = [];
  const headings: { title: string; start: number }[] = [];
  const landing: number[] = [];
  for (const raw of input.ingredients) {
    landing.push(ingredients.length);
    const text = standardIngredient(raw);
    if (!text) continue;
    const heading = ingredientHeading(text);
    if (heading) headings.push({ title: heading, start: ingredients.length });
    else ingredients.push(text);
  }

  const sections: { title: string; start: number }[] = [];
  const moved = [
    ...input.ingredientSections.map((section) => ({
      title: collapse(section.title).replace(/^[:\s]+|[:\s]+$/g, ""),
      start: landing[section.start] ?? ingredients.length,
    })),
    ...headings,
  ].sort((a, b) => a.start - b.start);
  for (const section of moved) {
    if (!section.title || section.start >= ingredients.length) continue;
    if (sections.at(-1)?.start === section.start) sections.pop();
    sections.push(section);
  }

  const steps: string[] = [];
  const origin: number[] = [];
  input.steps.forEach((raw, index) => {
    const step = cleanStep(raw);
    if (!step) return;
    steps.push(step);
    origin.push(index);
  });
  const stepTimestamps = input.stepTimestamps.length > 0 ? origin.map((i) => input.stepTimestamps[i] ?? null) : [];
  let stepImages = input.stepImages.length > 0 ? origin.map((i) => input.stepImages[i] ?? null) : [];
  if (stepImages.every((image) => image === null)) stepImages = [];

  const seen = new Set<string>();
  const tags: string[] = [];
  for (const raw of input.tags) {
    const tag = normalizeCategory(raw);
    if (tag && !seen.has(tag.toLowerCase())) {
      seen.add(tag.toLowerCase());
      tags.push(tag);
    }
  }

  const wantToCook = input.wantToCook;
  const rating = input.rating != null && input.rating >= 1 && input.rating <= 5 ? input.rating : undefined;

  return {
    id,
    title: collapse(input.title),
    summary: input.summary.trim(),
    servings: positive(input.servings),
    prepMinutes: positive(input.prepMinutes),
    cookMinutes: positive(input.cookMinutes),
    ingredients,
    ingredientSections: sections,
    steps,
    stepTimestamps,
    stepImages,
    tags,
    sourceURL: webURL(input.sourceURL),
    imageURL: webURL(input.imageURL),
    notes: input.notes.trim(),
    isFavorite: input.isFavorite,
    rating,
    wantToCook,
    queuedAt: wantToCook ? (input.queuedAt ?? existing?.queuedAt ?? isoDate(now)) : undefined,
    timeline: input.timeline,
    createdAt: existing?.createdAt ?? input.createdAt ?? isoDate(now),
    updatedAt: isoDate(now),
  };
}
