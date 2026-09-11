# 🧩 For plugin authors

The relevant functions for handling markdown files is to be find on the API namespace.

```lua
local api = require("md-drafting").api
```

| Name | What it is |
|---|---|
| `api.syntax` | Every markdown construct the plugin knows, as pure functions over strings — `format_link`, `parse_links`, `parse_list_item`, `parse_checkbox`, `parse_heading`, `format_anchor`, `parse_frontmatter`, and the rest |
| `api.section` | The "regenerate fully between fixed markers" mechanism the TOC is built on — `open_marker`, `close_marker`, `find`, `regenerate` |

