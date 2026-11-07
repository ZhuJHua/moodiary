# moodiary_mcp

Local [Model Context Protocol](https://modelcontextprotocol.io) server: a switch
in **Settings → MCP** turns the phone into an MCP endpoint so other MCP clients
(Claude Desktop, Cursor, VS Code, any SDK client) on the same device or the same
Wi-Fi can read, search, create, edit and delete diaries.

Nothing leaves the device unless a client you configured asks for it, and every
request must present the bearer token shown in the settings page.

## What it speaks

| Piece | Detail |
| --- | --- |
| Protocol versions | `2025-06-18`, `2025-03-26`, `2024-11-05` (negotiated at `initialize`) |
| Transport | Streamable HTTP on `/mcp` (POST, GET SSE stream, DELETE) and the legacy HTTP+SSE pair `/sse` + `/messages` for 2024-11-05 clients |
| Capabilities | `tools`, `resources`, `prompts`, `logging`, `completions` |
| Methods | `initialize`, `ping`, `tools/list`, `tools/call`, `resources/list`, `resources/templates/list`, `resources/read`, `prompts/list`, `prompts/get`, `logging/setLevel`, `completion/complete` |
| Notifications | server → client `notifications/message`, `notifications/progress`, `notifications/resources/updated`; client → server `notifications/initialized`, `notifications/cancelled` |
| Errors | JSON-RPC 2.0 (`-32700`, `-32600`, `-32601`, `-32602`, `-32603`), MCP `-32002` for a missing resource, `-32800` for cancellation; failing tools answer with `isError: true` results instead of protocol errors |

List endpoints page at 50 items with the opaque `nextCursor` from the previous
response.

## Security model

- **Bearer token, always.** A 32-byte random token is generated on first start and
  kept in secure storage. Requests without `Authorization: Bearer <token>` are
  rejected with `401`; the token can be rotated from the settings page, which
  restarts the server and invalidates connected clients until they are updated.
- **Loopback by default.** The server binds `127.0.0.1`, so only clients running
  on the same device can reach it. The LAN switch binds every interface and is
  what you need for a desktop client; treat it as publishing private data on your
  Wi-Fi and prefer a trusted network.
- **DNS-rebinding defence.** Requests carrying an `Origin` header are only
  accepted from `localhost` / `127.0.0.1` / `[::1]` origins (or the request's own
  host). `OPTIONS` preflight is answered for those origins only.
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
```

## Connecting a client

Claude Desktop (`claude_desktop_config.json`) style configuration for a client
that supports Streamable HTTP:

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
same `Authorization` header. Clients that only speak stdio can bridge with
`npx mcp-remote http://<ip>:8765/mcp --header "Authorization: Bearer <token>"`.

## Catalog

`buildMoodiaryRegistry` (`lib/src/tools/register_moodiary_tools.dart`) freezes the
catalog once per server start, which is why `listChanged` stays `false` for
tools/prompts and `subscribe` stays `false` for resources: changes are pushed as
`notifications/resources/updated` for the URIs the database touched instead.

- Tools: diary CRUD, search, links/tags, categories, statistics, server info.
- Resources: `moodiary://categories`, `moodiary://diaries/recent`,
  `moodiary://stats/overview`, template `moodiary://diary/{id}`.
- Prompts: `daily_review`, `summarize_period`, `find_connections`.

## Lifecycle

`McpService` (DI singleton) owns one `McpServer` + one transport. The settings
switch persists `mcpEnabled` / `mcpPort` / `mcpAllowLan` in KV and the token in
secure KV; `bootstrap.dart` calls `restore()` at startup so an enabled server
comes back, and the app-lock observer calls `pause()` / `resume()`.
