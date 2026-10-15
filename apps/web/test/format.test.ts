import { describe, expect, it } from "vitest";
import { clock, dataUrlToBlob, findTimers, mealForHour, safeHref, secondsFromClock, startOfWeek, youTubeID } from "../src/lib/format.js";

describe("format helpers", () => {
  it("round-trips step times", () => {
    expect(clock(95)).toBe("1:35");
    expect(clock(3725)).toBe("1:02:05");
    expect(secondsFromClock("1:35")).toBe(95);
    expect(secondsFromClock("1:02:05")).toBe(3725);
    expect(secondsFromClock("soon")).toBeNull();
  });

  it("finds timers in step text, using the upper end of a range", () => {
    expect(findTimers("Bake 20 to 25 minutes, then rest 10 min.")).toEqual([
      { label: "20 to 25 minutes", seconds: 1500 },
      { label: "10 min", seconds: 600 },
    ]);
    expect(findTimers("Simmer for 1.5 hours")).toEqual([{ label: "1.5 hours", seconds: 5400 }]);
    expect(findTimers("Stir well.")).toEqual([]);
  });

  it("recognizes YouTube links", () => {
    expect(youTubeID("https://www.youtube.com/watch?v=abcDEF12345")).toBe("abcDEF12345");
    expect(youTubeID("https://youtu.be/abcDEF12345?t=4")).toBe("abcDEF12345");
    expect(youTubeID("https://www.youtube.com/shorts/abcDEF12345")).toBe("abcDEF12345");
    expect(youTubeID("https://example.com/watch?v=abc")).toBeUndefined();
  });

  it("only turns web addresses into links", () => {
    expect(safeHref("https://example.com/a")).toBe("https://example.com/a");
    expect(safeHref("javascript:alert(1)")).toBeUndefined();
    expect(safeHref("data:text/html,x")).toBeUndefined();
    expect(safeHref("nonsense")).toBeUndefined();
  });

  it("decodes data URLs without fetch", async () => {
    const blob = dataUrlToBlob("data:image/jpeg;base64,/9j/4AAQ")!;
    expect(blob.type).toBe("image/jpeg");
    expect([...new Uint8Array(await blob.arrayBuffer())]).toEqual([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
    expect(dataUrlToBlob("https://example.com/a.jpg")).toBeNull();
    expect(dataUrlToBlob("data:image/png;base64,***")).toBeNull();
  });

  it("starts weeks on the chosen day and picks a meal by hour", () => {
    const wednesday = new Date(2026, 9, 14);
    expect(startOfWeek(wednesday, 0).getDate()).toBe(11);
    expect(startOfWeek(wednesday, 1).getDate()).toBe(12);
    expect([8, 12, 16, 19, 23].map(mealForHour)).toEqual(["breakfast", "lunch", "snack", "dinner", "snack"]);
  });
});
