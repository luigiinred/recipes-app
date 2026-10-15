export function formatMinutes(minutes: number): string {
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours === 0) return `${rest} min`;
  return rest === 0 ? `${hours} hr` : `${hours} hr ${rest} min`;
}

export function clock(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  const two = (n: number) => String(n).padStart(2, "0");
  return h > 0 ? `${h}:${two(m)}:${two(s)}` : `${m}:${two(s)}`;
}

export function secondsFromClock(text: string): number | null {
  const parts = text.split(":").map((part) => part.trim());
  if (parts.length === 0 || parts.length > 3 || parts.some((part) => !/^\d+$/.test(part))) return null;
  return parts.reduce((total, part) => total * 60 + Number(part), 0);
}

export function dayKey(date: Date): string {
  const two = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${two(date.getMonth() + 1)}-${two(date.getDate())}`;
}

export function dateFromKey(key: string): Date {
  const [year, month, day] = key.split("-").map(Number);
  return new Date(year!, month! - 1, day!);
}

export function addDays(date: Date, days: number): Date {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

/** The first day of the week containing `date`; `weekStart` is 0 for Sunday, 1 for Monday. */
export function startOfWeek(date: Date, weekStart: number): Date {
  const offset = (date.getDay() - weekStart + 7) % 7;
  return addDays(new Date(date.getFullYear(), date.getMonth(), date.getDate()), -offset);
}

export type Meal = "breakfast" | "lunch" | "dinner" | "snack";
export const MEAL_NAMES: Meal[] = ["breakfast", "lunch", "dinner", "snack"];
export const mealTitle = (meal: string): string => meal.charAt(0).toUpperCase() + meal.slice(1);

/** Breakfast until late morning, lunch through early afternoon, a snack mid-afternoon, dinner in the evening. */
export function mealForHour(hour: number): Meal {
  if (hour >= 4 && hour < 11) return "breakfast";
  if (hour >= 11 && hour < 15) return "lunch";
  if (hour >= 15 && hour < 17) return "snack";
  if (hour >= 17 && hour < 22) return "dinner";
  return "snack";
}

/** Only web links become `href`s: stored values may come from anywhere. */
export function safeHref(value: string | null | undefined): string | undefined {
  if (!value) return undefined;
  try {
    const url = new URL(value);
    return url.protocol === "http:" || url.protocol === "https:" ? url.toString() : undefined;
  } catch {
    return undefined;
  }
}

export function youTubeID(value: string | null | undefined): string | undefined {
  if (!value) return undefined;
  try {
    const url = new URL(value);
    const host = url.hostname.replace(/^www\.|^m\./, "");
    if (host === "youtu.be") return url.pathname.split("/")[1] || undefined;
    if (host === "youtube.com" || host === "music.youtube.com") {
      if (url.pathname === "/watch") return url.searchParams.get("v") ?? undefined;
      const match = /^\/(?:shorts|embed|live)\/([\w-]{6,})/.exec(url.pathname);
      return match?.[1];
    }
  } catch {
    /* not a URL */
  }
  return undefined;
}

/** A base64 data URL as a Blob. (`fetch` can't read these under the server's content security policy.) */
export function dataUrlToBlob(url: string): Blob | null {
  const match = /^data:([\w/+.-]+);base64,([\s\S]*)$/.exec(url);
  if (!match) return null;
  try {
    return new Blob([Uint8Array.from(atob(match[2]!), (char) => char.charCodeAt(0))], { type: match[1]! });
  } catch {
    return null;
  }
}

/** Scales a photo down to at most `maxSide` pixels and re-encodes it as JPEG, as the apps do before saving. */
export async function resizePhoto(file: Blob, maxSide = 2000): Promise<Blob> {
  try {
    const bitmap = await createImageBitmap(file);
    const scale = Math.min(1, maxSide / Math.max(bitmap.width, bitmap.height));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(1, Math.round(bitmap.width * scale));
    canvas.height = Math.max(1, Math.round(bitmap.height * scale));
    const context = canvas.getContext("2d");
    if (!context) return file;
    context.fillStyle = "#fff";
    context.fillRect(0, 0, canvas.width, canvas.height);
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    bitmap.close();
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.85));
    return blob ?? file;
  } catch {
    return file;
  }
}

/** Timers a step mentions: "bake 20 to 25 minutes" → 25 min. */
export function findTimers(text: string): { label: string; seconds: number }[] {
  const timers: { label: string; seconds: number }[] = [];
  const pattern = /(\d+(?:\.\d+)?)(?:\s*(?:-|–|to)\s*(\d+(?:\.\d+)?))?\s*(hours?|hrs?|minutes?|mins?|seconds?|secs?)\b/gi;
  for (const match of text.matchAll(pattern)) {
    const amount = Number(match[2] ?? match[1]);
    const unit = match[3]!.toLowerCase();
    const factor = unit.startsWith("h") ? 3600 : unit.startsWith("m") ? 60 : 1;
    timers.push({ label: match[0], seconds: Math.round(amount * factor) });
  }
  return timers;
}
