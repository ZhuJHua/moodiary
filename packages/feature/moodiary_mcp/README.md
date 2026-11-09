# moodiary_mcp

Local [Model Context Protocol](https://modelcontextprotocol.io) server: a switch
in **Settings → MCP** turns the phone into an MCP endpoint so other MCP clients
(Claude Desktop, Cursor, VS Code, any SDK client) on the same device or the same
Wi-Fi can read, search, create, edit and delete diaries.

Nothing leaves the device unless a client you configured asks for it. A
loopback-only server can run without a password; as soon as LAN access is on the
bearer token shown in the settings page is mandatory.

## What it speaks

| Piece | Detail |
| --- | --- |
| Protocol versions | `2025-06-18`, `2025-03-26`, `2024-11-05` (negotiated at `initialize`) |
| Transport | Streamable HTTP on `/mcp` (POST, GET SSE stream, DELETE) and the legacy HTTP+SSE pair `/sse` + `/messages` for 2024-11-05 clients |
| Capabilities | `tools`, `resources`, `prompts`, `logging`, `completions` |
| Methods | `initialize`, `ping`, `tools/list`, `tools/call`, `resources/list`, `resources/templates/list`, `resources/read`, `prompts/list`, `prompts/get`, `logging/setLevel`, `completion/complete` |
| Notifications | server → client `notifications/message`, `notifications/progress`, `notifications/resources/updated`; client → server `notifications/initialized`, `notifications/cancelled` |
| Icon | 512×512 PNG advertised as `serverInfo.icons` in `initialize` (plus `serverInfo.websiteUrl`) and served at `GET /icon.png` |
| Errors | JSON-RPC 2.0 (`-32700`, `-32600`, `-32601`, `-32602`, `-32603`), MCP `-32002` for a missing resource, `-32800` for cancellation; failing tools answer with `isError: true` results instead of protocol errors |

List endpoints page at 50 items with the opaque `nextCursor` from the previous
response.

## Security model

There are two modes, and the settings page picks one:

- **Loopback only (default).** The server binds `127.0.0.1`, so only programs
  running on the same device can reach it. The password (bearer token) is
  generated and enforced unless the user turns it off; with it off, any local
  process can read and write the diary, which is the trade-off for one-click
  client setup.
- **LAN access.** The LAN switch binds every interface so a desktop client can
  connect over Wi-Fi. The bearer token is then always required: `McpService`
  answers "token required" whenever LAN access is on, whatever the stored password
  switch says, and `IoMcpTransport.start` refuses a config that tries the opposite
  with an `ArgumentError`. So `requireToken: false` combined with
  `allowLan: true` cannot be expressed by the app.

Details:

- **Bearer token, optional on loopback.** A 32-byte random token is generated on
  first use and kept in secure storage. When the password is on, requests without
  `Authorization: Bearer <token>` are rejected with `401`; both transports (`/mcp`
  and `/sse` + `/messages`) use the same token, so a client can switch transports
  without a new secret. Rotating the token from the settings page restarts the
  server and invalidates connected clients until they are updated. While the LAN
  switch is on the requirement stays on, whatever the stored password switch says.
- **DNS-rebinding defence.** Requests carrying an `Origin` header are only
  accepted from `localhost` / `127.0.0.1` / `[::1]` origins (or the request's own
  host). `OPTIONS` preflight is answered for those origins only. This holds in
  both modes: dropping the password does not drop the origin rule.
- **The icon is public.** `GET` / `HEAD /icon.png` answers the embedded app icon
  without a token, because an icon is not diary data and clients fetch it before
  they hold a session. It is still behind the origin rule and its body is the
  fixed embedded image.
- **Locked app, closed port.** The server is paused while the app lock is
  engaged and resumed afterwards.
- **No media transfer.** Image/audio/video contents are never sent; tools expose
  the file names and the diary body only.

## Endpoints

```
POST   /mcp                          Streamable HTTP (JSON-RPC in, JSON or SSE out)
GET    /mcp                          SSE stream of server notifications (needs Mcp-Session-Id)
DELETE /mcp                          Terminate the session
GET    /sse                          Legacy HTTP+SSE stream (first event: endpoint)
POST   /messages?sessionId=<id>      Legacy HTTP+SSE request channel (202 Accepted)
GET    /icon.png                     Server icon, PNG (no token required)
HEAD   /icon.png                     Same headers, no body
```

## Server icon

The app's launcher mark is embedded as a 512×512 PNG
(`lib/src/server/server_icon.dart`, so the transport answers it from any isolate
without the asset bundle) and advertised in the `initialize` result of **both**
transports:

```json
"serverInfo": {
  "name": "moodiary",
  "title": "Moodiary",
  "version": "1.2.3",
  "websiteUrl": "https://github.com/ZhuJHua/moodiary",
  "icons": [
    {
      "src": "http://<host>/icon.png",
      "mimeType": "image/png",
      "sizes": ["512x512"]
    }
  ]
}
```

`<host>` is the `Host` header of the request that asked, so a LAN client is told
its LAN address and a loopback client the loopback one. The entry follows the
`icons` schema standardised by SEP-973 (`src` / `mimeType` / `sizes`), and it is
sent on `serverInfo` whatever revision was negotiated: unknown fields are ignored,
so the protocol version is left alone. Clients that read `serverInfo.icons` (MCP
Inspector and other spec-aware clients) show the icon; Claude Desktop and Claude
Code still fall back to their own placeholder tile for third-party servers, and
clients that do not know the field ignore it entirely.

## Connecting a client

On the same device with the password switched off:

```json
{
  "mcpServers": {
    "moodiary": {
      "type": "http",
      "url": "http://127.0.0.1:8765/mcp"
    }
  }
}
```

Over the LAN, where the password is always required:

```json
{
  "mcpServers": {
    "moodiary": {
      "type": "http",
      "url": "http://192.168.1.20:8765/mcp",
      "headers": { "Authorization": "Bearer <token from Settings → MCP>" }
    }
  }
}
```

For older clients, point the SSE transport at `http://<ip>:8765/sse` with the
same `Authorization` header (loopback without a password needs none). Clients that
only speak stdio can bridge with
`npx mcp-remote http://<ip>:8765/mcp --header "Authorization: Bearer <token>"`;
drop `--header` only for a loopback server without a password.

## Catalog

`buildMoodiaryRegistry` (`lib/src/tools/register_moodiary_tools.dart`) freezes the
catalog once per server start, which is why `listChanged` stays `false` for
tools/prompts and `subscribe` stays `false` for resources: changes are pushed as
`notifications/resources/updated` for the URIs the database touched instead.

The handlers keep the MCP contract here (names, schemas, `McpToolResult` shapes)
and delegate the diary rules to `moodiary_diary_ops`, which the in-app assistant
uses too.

- Tools: diary CRUD, search, links/tags, categories, statistics, server info.
- Resources: `moodiary://categories`, `moodiary://diaries/recent`,
  `moodiary://stats/overview`, template `moodiary://diary/{id}`.
- Prompts: `daily_review`, `summarize_period`, `find_connections`.

### Body representations

Diary bodies are stored as Tiptap documents, so the read and write tools take an
explicit representation instead of guessing:

- `get_diary`: `format` is `markdown` (default), `text`, `tiptap` or `json`; the
  latter two return the raw stored document and win over the render flags.
  `renderMarkdown` (default `true`) set to `false` returns the plain text body
  instead of Markdown — no syntax, media as `[image: name]` placeholders.
  `renderLinks` (default `true`) set to `false` renders a diary link (double
  link) as its label text instead of `[label](moodiary://diary/<id>)`; it only
  affects Markdown output. The answer's `contentFormat` names the representation
  actually returned.
- `list_diaries` / `search_diaries`: the preview is one plain text line, cut to
  200 characters. `renderMarkdown` (default `false`) set to `true` returns the
  Markdown body excerpt instead, so headings and lists survive.
- `create_diary` / `update_diary`: `contentFormat` is `markdown` (default) or
  `text`. The default parses `content` as Markdown and stores the editor
  document, `text` stores literal paragraphs so Markdown syntax stays visible;
  it applies to `content` only.

## Lifecycle

`McpService` (DI singleton) owns one `McpServer` + one transport. The settings
switch persists `mcpEnabled` / `mcpPort` / `mcpAllowLan` / `mcpRequireToken` in KV
and the token in secure KV; `bootstrap.dart` calls `restore()` at startup so an
enabled server comes back, and the app-lock observer calls `pause()` /
`resume()`. `updateConfig(port:, lan:, requireToken:)` persists the new settings
and restarts a running server, because none of the three can change under a live
socket. `start()` reads secure storage only when the token is required: a
token-less loopback server starts with an empty token and keeps the stored one for
the moment the requirement comes back.
