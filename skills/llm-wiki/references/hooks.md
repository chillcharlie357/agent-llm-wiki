# Hook integration

`llm-wiki-hook` is the stable adapter between Agent lifecycle events and the Wiki. It reads optional event data from stdin and uses `LLM_WIKI_ROOT` to locate the vault.

## Events

```sh
# Print relevant long-term memories to stdout.
llm-wiki-hook recall
llm-wiki-hook session-start
llm-wiki-hook prompt

# Copy a transcript or stdin payload into the review inbox.
llm-wiki-hook capture
llm-wiki-hook session-end
```

Environment variables:

- `LLM_WIKI_ROOT`: initialized Wiki directory.
- `LLM_WIKI_QUERY`: explicit recall query.
- `LLM_WIKI_TRANSCRIPT`: transcript file to capture.
- `LLM_WIKI_SOURCE`: provenance label for an inbox item.
- `LLM_WIKI_RECALL_LIMIT`: maximum recall results; default `5`.

The adapter understands the common JSON string fields `prompt`, `cwd`, and `transcript_path`. Harness plugins may set the environment variables directly when their event schema differs.

## Claude Code

Add command hooks to the project's `.claude/settings.json`, replacing `/path/to/wiki` when needed:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "LLM_WIKI_ROOT=/path/to/wiki llm-wiki-hook session-start"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "LLM_WIKI_ROOT=/path/to/wiki llm-wiki-hook prompt"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "LLM_WIKI_ROOT=/path/to/wiki llm-wiki-hook session-end"
          }
        ]
      }
    ]
  }
}
```

`SessionStart` and `UserPromptSubmit` stdout is available to Claude as context. `SessionEnd` sends `transcript_path`; the adapter copies that file to the review inbox.

## Codex, Trae, OpenCode, and Pi

Use the harness lifecycle surface to call the same adapter:

| Lifecycle | Command |
| --- | --- |
| Session starts | `LLM_WIKI_ROOT=/path/to/wiki llm-wiki-hook session-start` |
| User prompt submitted | `LLM_WIKI_ROOT=/path/to/wiki llm-wiki-hook prompt` |
| Session ends | `LLM_WIKI_ROOT=/path/to/wiki llm-wiki-hook session-end` |

For harnesses whose hook API is a TypeScript plugin or extension, spawn this command, forward the event JSON to stdin, and add recall stdout to the model context. Do not write long-term pages directly from the lifecycle callback; capture to the inbox and let the `llm-wiki` Skill review it.
