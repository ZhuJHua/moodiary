# moodiary_mcp

Android-only local Model Context Protocol (MCP) server for reading, searching
and editing diaries from an MCP client.

Enable it in **Settings → Features → MCP**, then copy the endpoint and token
into a client that supports Streamable HTTP. The endpoint is
`http://<host>:<port>/mcp` (default port `8765`). Every request requires
`Authorization: Bearer <token>`, including loopback requests.

Loopback mode binds to `127.0.0.1` for clients on the phone. Enable LAN access
to connect from another device using the phone's Wi-Fi address. LAN traffic is
unencrypted, so use a trusted network. The server is available while the app
process is alive; while it runs, an Android foreground service with an ongoing notification keeps it alive.

The catalog includes:

- Diary tools: `get_diary`, `create_diary`, `update_diary`, `delete_diary`, `search_diaries`, `get_diary_links`, `list_tags`.
- Category tools: `list_categories`, `create_category`, `update_category`, `delete_category`.
- Statistics tools: `get_stats`.
- Media tools: `list_diary_media`, `read_diary_media`, `add_diary_image`, `add_diary_attachment`.
- Prompts: `daily_review`, `summarize_period`, `find_connections`.

`delete_diary` moves diaries to the recycle bin; permanent deletion is an in-app action.
`read_diary_media` returns images only; audio, video and file attachments return a tool error.

Categories are a flat list. Each category reports its own visible diary count.

`search_diaries` supports `mode=auto` (keywords plus meaning), `keyword` and
`meaning`. Meaning search depends on the on-device semantic index; when it is
unavailable, search falls back to keywords and returns `semanticAvailable: false`.
Each hit includes `via` and `similarity`. Pages default to 10 rows, capped at 50.
When meaning search runs, each path retrieves a fixed 50 candidates, applies
filters, fuses the results and optionally sorts them before paging. Offsets past
the combined results return no rows. `totalIsLowerBound: true` means at least one
path reached its candidate cap, so the results may be incomplete.

For Google Play, declare `specialUse` as a user-enabled local MCP server and demonstrate its switch, notification and Stop action.

Known limits: when MCP and an open in-app editor save the same diary, the later
save wins. Tags are case-sensitive and are not included in full-text search;
use the `search_diaries` tag filter instead.
