import dns from "node:dns";
import http from "node:http";
import https from "node:https";
import net from "node:net";
import { pipeline } from "node:stream";
import zlib from "node:zlib";
import { HttpError } from "../errors.js";

const blocked = new net.BlockList();
for (const [address, prefix] of [
  ["0.0.0.0", 8],
  ["10.0.0.0", 8],
  ["100.64.0.0", 10],
  ["127.0.0.0", 8],
  ["169.254.0.0", 16],
  ["172.16.0.0", 12],
  ["192.0.0.0", 24],
  ["192.168.0.0", 16],
  ["198.18.0.0", 15],
  ["224.0.0.0", 3],
] as const) {
  blocked.addSubnet(address, prefix, "ipv4");
}
for (const [address, prefix] of [
  ["::", 128],
  ["::1", 128],
  ["fc00::", 7],
  ["fe80::", 10],
  ["ff00::", 8],
  ["::", 96],
  ["64:ff9b::", 96],
  ["2001::", 32],
  ["2002::", 16],
  ["fec0::", 10],
] as const) {
  blocked.addSubnet(address, prefix, "ipv6");
}

/** Loopback, private, link-local and other addresses a public recipe site never lives at. */
export function isPrivateAddress(address: string): boolean {
  const mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/i.exec(address);
  if (mapped) return isPrivateAddress(mapped[1]!);
  const family = net.isIP(address);
  if (family === 0) return true;
  return blocked.check(address, family === 4 ? "ipv4" : "ipv6");
}

export interface FetchOptions {
  allowPrivate?: boolean;
  maxBytes: number;
  timeoutMs?: number;
  deadlineMs?: number;
  maxRedirects?: number;
  accept?: string;
}

export interface FetchedResponse {
  status: number;
  finalUrl: URL;
  contentType: string;
  body: Buffer;
}

const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15";

function guardedLookup(allowPrivate: boolean): net.LookupFunction {
  return (hostname, options, callback) => {
    dns.lookup(hostname, { ...options, all: true }, (error, addresses) => {
      if (error) return callback(error, "", 4);
      const list = addresses as dns.LookupAddress[];
      const allowed = allowPrivate ? list : list.filter((entry) => !isPrivateAddress(entry.address));
      if (allowed.length === 0) return callback(new Error("That address isn't allowed."), "", 4);
      if (options.all) return (callback as unknown as (e: null, a: dns.LookupAddress[]) => void)(null, allowed);
      callback(null, allowed[0]!.address, allowed[0]!.family);
    });
  };
}

function requestOnce(url: URL, options: FetchOptions, signal: AbortSignal): Promise<{ response: http.IncomingMessage }> {
  return new Promise((resolve, reject) => {
    const client = url.protocol === "https:" ? https : http;
    const request = client.request(
      url,
      {
        method: "GET",
        lookup: guardedLookup(options.allowPrivate ?? false),
        timeout: options.timeoutMs ?? 15_000,
        signal,
        headers: {
          "user-agent": USER_AGENT,
          accept: options.accept ?? "text/html,application/xhtml+xml,*/*;q=0.8",
          "accept-encoding": "gzip, deflate, br",
        },
      },
      (response) => resolve({ response }),
    );
    request.on("timeout", () => request.destroy(new Error("The site took too long to respond.")));
    request.on("error", reject);
    request.end();
  });
}

async function readBody(response: http.IncomingMessage, maxBytes: number): Promise<Buffer> {
  const encoding = String(response.headers["content-encoding"] ?? "").toLowerCase();
  const decoder =
    encoding === "gzip" ? zlib.createGunzip()
    : encoding === "deflate" ? zlib.createInflate()
    : encoding === "br" ? zlib.createBrotliDecompress()
    : null;
  // pipeline() tears the decoder down when the response dies, so a stalled or aborted transfer ends instead of hanging.
  const source: AsyncIterable<Buffer> = decoder ? pipeline(response, decoder, () => {}) : response;
  const chunks: Buffer[] = [];
  let total = 0;
  for await (const chunk of source) {
    total += (chunk as Buffer).length;
    if (total > maxBytes) {
      response.destroy();
      throw new HttpError(502, "That page is too large to import.");
    }
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks);
}

/** GET a public web page or image: http(s) only, every hop checked against private ranges, size and time limited. */
export async function safeFetch(rawUrl: string | URL, options: FetchOptions): Promise<FetchedResponse> {
  let url = new URL(rawUrl);
  // One deadline for the whole fetch, redirects and slow trickles included.
  const signal = AbortSignal.timeout(options.deadlineMs ?? 30_000);
  for (let hop = 0; hop <= (options.maxRedirects ?? 5); hop += 1) {
    if (url.protocol !== "http:" && url.protocol !== "https:") throw new HttpError(400, "Only web addresses can be imported.");
    const host = url.hostname.replace(/^\[|\]$/g, "");
    if (!options.allowPrivate && net.isIP(host) !== 0 && isPrivateAddress(host)) throw new HttpError(400, "That address isn't allowed.");
    let response: http.IncomingMessage;
    try {
      ({ response } = await requestOnce(url, options, signal));
    } catch (error) {
      throw new HttpError(502, error instanceof Error ? error.message : "Couldn't reach that address.");
    }
    const status = response.statusCode ?? 0;
    const location = response.headers.location;
    if (status >= 300 && status < 400 && location) {
      response.resume();
      url = new URL(location, url);
      continue;
    }
    try {
      const body = await readBody(response, options.maxBytes);
      return { status, finalUrl: url, contentType: String(response.headers["content-type"] ?? ""), body };
    } catch (error) {
      if (error instanceof HttpError) throw error;
      throw new HttpError(502, "Couldn't read that page.");
    }
  }
  throw new HttpError(502, "That address redirects too many times.");
}
