import http from "node:http";
import type { AddressInfo } from "node:net";
import { afterEach, describe, expect, it } from "vitest";
import { clean, importedTitle, jsonLdBlocks, minutes, openGraphImage, parseRecipePage } from "../src/importers/recipe-page.js";
import { isPrivateAddress, safeFetch } from "../src/importers/safe-fetch.js";
import { suggestTags } from "../src/importers/tags.js";
import { client, makeServer, TINY_JPEG, type TestServer } from "./helpers.js";

const PAGE = new URL("https://example.com/recipes/pancakes");

const html = (jsonLd: unknown, head = "") =>
  `<html><head>${head}<script type="application/ld+json">${typeof jsonLd === "string" ? jsonLd : JSON.stringify(jsonLd)}</script></head><body></body></html>`;

describe("recipe pages", () => {
  it("reads schema.org data, including @graph, sections and entities", () => {
    const parsed = parseRecipePage(
      html({
        "@context": "https://schema.org",
        "@graph": [
          { "@type": "WebSite", name: "Example" },
          {
            "@type": ["Recipe", "Thing"],
            name: "Fluffy Pancakes Recipe by Tasty",
            description: "Light &amp; airy",
            recipeYield: ["8", "8 pancakes"],
            prepTime: "PT10M",
            cookTime: "PT1H5M",
            keywords: "breakfast, brunch",
            recipeCategory: ["Breakfast"],
            image: [{ "@type": "ImageObject", url: "/photos/pancakes.jpg" }],
            recipeIngredient: ["1½ cups flour", "2 eggs"],
            recipeInstructions: [
              { "@type": "HowToSection", name: "Batter", itemListElement: [{ "@type": "HowToStep", text: "Whisk the <b>eggs</b>." }] },
              { "@type": "HowToStep", text: "Fry." },
            ],
          },
        ],
      }),
      PAGE,
    )!;
    expect(parsed.draft).toMatchObject({
      title: "Fluffy Pancakes",
      summary: "Light & airy",
      servings: 8,
      prepMinutes: 10,
      cookMinutes: 65,
      ingredients: ["1½ cups flour", "2 eggs"],
      steps: ["Whisk the eggs.", "Fry."],
      sourceURL: "https://example.com/recipes/pancakes",
      tags: ["Breakfast"],
    });
    expect(parsed.imageURL).toBe("https://example.com/photos/pancakes.jpg");
  });

  it("falls back to the Open Graph photo and tolerates CDATA wrappers", () => {
    const parsed = parseRecipePage(
      html("// <![CDATA[\n" + JSON.stringify({ "@type": "Recipe", name: "Toast", recipeInstructions: "Toast it.\nButter it." }) + "\n// ]]>", '<meta property="og:image" content="https://cdn.example.com/toast.jpg">'),
      PAGE,
    )!;
    expect(parsed.draft.steps).toEqual(["Toast it.", "Butter it."]);
    expect(parsed.imageURL).toBe("https://cdn.example.com/toast.jpg");
  });

  it("returns null when there is no recipe", () => {
    expect(parseRecipePage("<html></html>", PAGE)).toBeNull();
    expect(parseRecipePage(html("{broken"), PAGE)).toBeNull();
    expect(parseRecipePage(html({ "@type": "Article", name: "News" }), PAGE)).toBeNull();
  });

  it("cleans titles, durations and tags like the apps", () => {
    expect(importedTitle("Amazing White Chocolate Chip Cookies | Preppy Kitchen")).toBe("Amazing White Chocolate Chip Cookies");
    expect(importedTitle("The Best Chewy Chocolate Chip Cookies Recipe by Tasty")).toBe("The Best Chewy Chocolate Chip Cookies");
    expect(minutes("PT1H30M")).toBe(90);
    expect(minutes("P1DT2H")).toBe(1560);
    expect(minutes("soon")).toBeUndefined();
    expect(suggestTags("Salmon Dinner", ["1 lb salmon"])).toEqual(["Fish", "Dinner"]);
    expect(suggestTags("Chicken noodle soup", ["1 chicken", "2 cups noodles"])).toEqual(["Chicken", "Soup"]);
  });
});

describe("hostile pages", () => {
  const timed = (work: () => unknown): number => {
    const start = performance.now();
    work();
    return performance.now() - start;
  };

  it("scans markup in linear time", () => {
    const size = 600_000;
    expect(timed(() => jsonLdBlocks("<script".repeat(size / 7)))).toBeLessThan(500);
    expect(timed(() => openGraphImage("<meta ".repeat(size / 6)))).toBeLessThan(500);
    expect(timed(() => clean("<".repeat(size)))).toBeLessThan(500);
    expect(timed(() => jsonLdBlocks("<script type='application/ld+json'>".repeat(size / 36)))).toBeLessThan(500);
  });

  it("still finds what it should", () => {
    expect(clean("a <b>bold</b> &amp; <i>fine</i>")).toBe("a bold & fine");
    expect(clean("1 < 2 and 3 > 2")).toBe("1  2");
    expect(jsonLdBlocks('<SCRIPT TYPE="application/ld+json">{"a":1}</SCRIPT><script>no</script>')).toEqual(['{"a":1}']);
    expect(openGraphImage('<meta name="x" content="no"><meta property="og:image" content="https://e.com/a.jpg">')).toBe("https://e.com/a.jpg");
  });
});

describe("outbound requests", () => {
  it.each(["127.0.0.1", "10.1.2.3", "172.16.0.1", "192.168.1.1", "169.254.169.254", "100.64.0.1", "0.0.0.0", "::1", "fc00::1", "fe80::1", "::ffff:127.0.0.1"])(
    "treats %s as private",
    (address) => expect(isPrivateAddress(address)).toBe(true),
  );
  it.each(["8.8.8.8", "93.184.216.34", "2606:2800:220:1:248:1893:25c8:1946"])("allows %s", (address) => expect(isPrivateAddress(address)).toBe(false));

  it.each(["::127.0.0.1", "64:ff9b::7f00:1", "2002:7f00:1::1", "fec0::1"])("blocks the tunnelled or deprecated form %s", (address) =>
    expect(isPrivateAddress(address)).toBe(true),
  );

  it("gives up on a gzip response that stalls instead of hanging", async () => {
    const stalled = http.createServer((_request, response) => {
      response.writeHead(200, { "content-encoding": "gzip", "content-type": "text/html" });
      response.write(Buffer.from([0x1f, 0x8b, 0x08, 0x00]));
    });
    await new Promise<void>((resolve) => stalled.listen(0, "127.0.0.1", resolve));
    const port = (stalled.address() as AddressInfo).port;
    try {
      await expect(safeFetch(`http://127.0.0.1:${port}/`, { maxBytes: 1000, allowPrivate: true, deadlineMs: 400, timeoutMs: 5000 })).rejects.toBeTruthy();
    } finally {
      stalled.closeAllConnections();
      await new Promise((resolve) => stalled.close(resolve));
    }
  }, 5000);

  it("refuses private and non-web addresses", async () => {
    await expect(safeFetch("http://127.0.0.1:9/", { maxBytes: 1000 })).rejects.toMatchObject({ status: 400 });
    await expect(safeFetch("http://[::1]/", { maxBytes: 1000 })).rejects.toMatchObject({ status: 400 });
    await expect(safeFetch("file:///etc/passwd", { maxBytes: 1000 })).rejects.toMatchObject({ status: 400 });
    await expect(safeFetch("http://localhost:9/", { maxBytes: 1000 })).rejects.toMatchObject({ status: 502 });
  });
});

describe("import endpoint", () => {
  let upstream: http.Server;
  let server: TestServer;
  afterEach(async () => {
    await server.cleanup();
    await new Promise((resolve) => upstream.close(resolve));
  });

  const serveUpstream = async () => {
    upstream = http.createServer((request, response) => {
      const base = `http://127.0.0.1:${(upstream.address() as AddressInfo).port}`;
      if (request.url === "/photo.jpg") {
        response.writeHead(200, { "content-type": "image/jpeg" }).end(Buffer.from(TINY_JPEG));
      } else if (request.url === "/old") {
        response.writeHead(301, { location: "/pancakes" }).end();
      } else if (request.url === "/pancakes") {
        response
          .writeHead(200, { "content-type": "text/html" })
          .end(html({ "@type": "Recipe", name: "Pancakes", image: `${base}/photo.jpg`, recipeIngredient: ["2 eggs"], recipeInstructions: ["Fry"] }));
      } else {
        response.writeHead(404).end();
      }
    });
    await new Promise<void>((resolve) => upstream.listen(0, "127.0.0.1", resolve));
    return `http://127.0.0.1:${(upstream.address() as AddressInfo).port}`;
  };

  it("imports a page and its photo as a draft, following redirects, without saving", async () => {
    server = await makeServer({ allowPrivateImports: true });
    const base = await serveUpstream();
    const api = await client(server);
    const result = await (await api.post("/api/import", { url: `${base}/old` })).json();
    expect(result.draft).toMatchObject({ title: "Pancakes", ingredients: ["2 eggs"], sourceURL: `${base}/pancakes` });
    expect(result.image).toMatch(/^data:image\/jpeg;base64,/);
    expect(await (await api.get("/api/recipes")).json()).toEqual([]);
    expect((await api.post("/api/import", { url: `${base}/missing` })).status).toBe(502);
  });

  it("won't fetch from the server's own network unless allowed", async () => {
    server = await makeServer();
    const base = await serveUpstream();
    const api = await client(server);
    const response = await api.post("/api/import", { url: `${base}/pancakes` });
    expect(response.status).toBe(400);
    expect((await api.post("/api/import", { url: "https://www.youtube.com/watch?v=abc" })).status).toBe(422);
    expect((await api.post("/api/import", { url: "not a url" })).status).toBe(422);
  });
});
