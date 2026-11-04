# server-auth Specification

## Purpose
Protects the self-hosted server's single library with one owner password, browser sessions and named access tokens for the CLI and other clients. Runs on the server; the web UI provides the setup, sign-in and token pages (see web-ui).

## Requirements

### Requirement: Single owner
The server SHALL have exactly one owner password and no user accounts. Every `/api` route except `GET /api/health`, `GET /api/session`, `POST /api/setup`, `POST /api/login` and `POST /api/logout` requires either a valid session cookie or a valid access token, and answers `401` without one.

#### Scenario: Closed until signed in
- **WHEN** an unauthenticated client requests `GET /api/recipes` or `GET /api/sync/files`
- **THEN** the server answers `401`
- **AND** `GET /api/health` still answers `200` with `{ "ok": true }`

### Requirement: Session status
`GET /api/session` SHALL return `authenticated` (whether the request's session cookie is valid), `setupRequired` (whether no password exists yet) and the server `version`.

#### Scenario: Fresh server
- **GIVEN** a server started without a password
- **WHEN** a browser requests `GET /api/session`
- **THEN** the answer has `setupRequired: true` and `authenticated: false`

### Requirement: First-run setup code
While no password exists, the server SHALL generate a random setup code, print it in the log at start-up and write it to `<data>/.server/setup-code` with owner-only permissions. `POST /api/setup` with `{ code, password }` sets the password only when the code matches; a wrong code is `403`, a password shorter than 8 characters is `422`, and once a password exists setup answers `409`. A successful setup removes the setup code file and signs the browser in.

#### Scenario: Completing setup
- **GIVEN** a server with no password
- **WHEN** a browser posts the printed code and an 8-character password to `/api/setup`
- **THEN** the server answers `200` and sets a `recipes_session` cookie
- **AND** a second setup attempt answers `409`

#### Scenario: Wrong code
- **WHEN** a browser posts a wrong code to `/api/setup`
- **THEN** the server answers `403` with a message saying the code is in the server log and the data folder

### Requirement: Seeded password
When `RECIPES_PASSWORD` is set and no password exists yet, the server SHALL use it as the owner password at start-up and skip the setup code. It is ignored once a password exists.

#### Scenario: Skipping setup
- **WHEN** a new server starts with `RECIPES_PASSWORD` set
- **THEN** `GET /api/session` reports `setupRequired: false`
- **AND** signing in with that password works

### Requirement: Password storage
The server SHALL store only an scrypt hash of the password (Unicode-normalized before hashing) together with the token hashes in `<data>/.server/auth.json`, and a random cookie-signing secret in `<data>/.server/secret`, both written with owner-only permissions.

#### Scenario: No plaintext on disk
- **WHEN** a password is set
- **THEN** `auth.json` holds a value beginning `scrypt$` and not the password itself

### Requirement: Sign in and out
`POST /api/login` with `{ password }` SHALL answer `200` and set the session cookie for the right password and `401` ("Wrong password.") otherwise, including while setup is pending. `POST /api/logout` clears the browser's cookie.

#### Scenario: Wrong password
- **WHEN** a browser posts a wrong password to `/api/login`
- **THEN** the server answers `401` and sets no cookie

### Requirement: Stateless session cookies
The session cookie `recipes_session` SHALL be an expiry time and nonce signed with an HMAC keyed by the server secret and the current password hash, valid for `SESSION_DAYS` days (default 30). It is `HttpOnly`, `SameSite=Lax`, `Path=/`, and `Secure` when the request arrived over HTTPS (or, with `TRUST_PROXY`, when `X-Forwarded-Proto` is `https`). A forged, malformed or expired cookie is treated as signed out.

#### Scenario: Cookie flags
- **WHEN** a browser signs in
- **THEN** the `Set-Cookie` header contains `HttpOnly` and `SameSite=Lax`

#### Scenario: Expired cookie
- **GIVEN** a correctly signed cookie whose expiry is in the past
- **WHEN** it is sent with `GET /api/recipes`
- **THEN** the server answers `401`

### Requirement: Changing the password
A signed-in client SHALL be able to change the password with `POST /api/password` and `{ current, next }`. A wrong current password is `403` and a new password shorter than 8 characters is `422`. A change invalidates every existing session, and the response sets a fresh session cookie for the browser that made it.

#### Scenario: Other browsers signed out
- **GIVEN** two signed-in browsers
- **WHEN** one changes the password
- **THEN** the other's next API request answers `401`
- **AND** the changing browser stays signed in with its new cookie
- **AND** the old password no longer signs in

### Requirement: Sign-in rate limit
The server SHALL count setup, sign-in and password-change attempts per client address and refuse further attempts with `429` after 10 failures within 15 minutes; a success resets the count. Attempts are counted before they are checked, so parallel guesses cannot all get through. With `TRUST_PROXY` on, the client address is the last entry of `X-Forwarded-For`; otherwise it is the connection's address, and the server logs one warning if it sees `X-Forwarded-For` without `TRUST_PROXY`.

#### Scenario: Too many guesses
- **WHEN** a client sends 10 wrong passwords and then the right one
- **THEN** the eleventh attempt answers `429`

#### Scenario: Parallel guesses
- **WHEN** a client sends 30 wrong passwords at once
- **THEN** 10 answer `401` and 20 answer `429`

### Requirement: Access tokens
A signed-in client SHALL be able to list (`GET /api/tokens`), create (`POST /api/tokens` with a `name` of 1 to 80 characters) and revoke (`DELETE /api/tokens/:id`) access tokens. A new token has the form `rcp_<random>` and its value is returned only once, in the `201` response; listings show `id`, `name`, `createdAt` and `lastUsedAt` but never the value, and only its SHA-256 hash is stored. A token sent as `Authorization: Bearer <token>` grants the same access as a session; an unknown or revoked token is `401`. `lastUsedAt` is updated at most once a minute. Revoking an unknown id is `404`.

#### Scenario: Token lifecycle
- **WHEN** a client creates a token named "iPhone"
- **THEN** the value starts with `rcp_` and does not appear in `GET /api/tokens`
- **AND** requests with `Authorization: Bearer <value>` succeed
- **AND** after `DELETE /api/tokens/<id>` answers `204`, the same requests answer `401`

### Requirement: Cross-site request protection
For requests authenticated by the session cookie, the server SHALL refuse methods other than `GET`, `HEAD` and `OPTIONS` with `403` when `Sec-Fetch-Site` is present and not `same-origin` or `none`, or when an `Origin` header's host differs from the request's `Host` (or `X-Forwarded-Host` with `TRUST_PROXY`). Requests authenticated by a bearer token are not subject to this check.

#### Scenario: Forged form post
- **GIVEN** a signed-in browser
- **WHEN** a page on `https://evil.example` makes it post to `/api/groceries`
- **THEN** the server answers `403` and adds nothing

#### Scenario: Own pages
- **WHEN** the same post comes with `Origin` matching the server's host
- **THEN** the server answers `201`
