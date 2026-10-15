import { useSyncExternalStore, type AnchorHTMLAttributes, type MouseEvent } from "react";

interface Location {
  path: string;
  search: URLSearchParams;
  state: unknown;
  key: string;
}

const snapshot = (): Location => ({
  path: window.location.pathname,
  search: new URLSearchParams(window.location.search),
  state: window.history.state,
  key: window.location.href + JSON.stringify(window.history.state ?? null),
});

let current = snapshot();
const listeners = new Set<() => void>();

function publish() {
  current = snapshot();
  listeners.forEach((listener) => listener());
}

window.addEventListener("popstate", publish);

export function useLocation(): Location {
  return useSyncExternalStore(
    (listener) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    () => current,
  );
}

export function navigate(to: string, options: { replace?: boolean; state?: unknown } = {}): void {
  if (options.replace) window.history.replaceState(options.state ?? null, "", to);
  else window.history.pushState(options.state ?? null, "", to);
  publish();
  window.scrollTo(0, 0);
}

export function Link({ to, state, onClick, children, ...rest }: { to: string; state?: unknown } & AnchorHTMLAttributes<HTMLAnchorElement>) {
  const handle = (event: MouseEvent<HTMLAnchorElement>) => {
    onClick?.(event);
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    if (rest.target && rest.target !== "_self") return;
    event.preventDefault();
    navigate(to, { state });
  };
  return (
    <a {...rest} href={to} onClick={handle}>
      {children}
    </a>
  );
}

export function recipesUrl(params: { id?: string; collection?: string; tag?: string; q?: string } = {}): string {
  const query = new URLSearchParams();
  if (params.collection && params.collection !== "all") query.set("collection", params.collection);
  if (params.tag) query.set("tag", params.tag);
  if (params.q) query.set("q", params.q);
  const suffix = query.toString();
  return `/recipes${params.id ? `/${params.id}` : ""}${suffix ? `?${suffix}` : ""}`;
}
