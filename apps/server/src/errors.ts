export class HttpError extends Error {
  constructor(
    readonly status: 400 | 401 | 403 | 404 | 409 | 412 | 413 | 415 | 422 | 429 | 502,
    message: string,
    readonly details?: unknown,
  ) {
    super(message);
  }
}
