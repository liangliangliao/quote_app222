# AI Assistant upload, Discover entry, and ChatGPT-style chat controls

## Scope

This patch upgrades the AI assistant chat module with:

- Image/file attachments in the chat input.
- Local attachment persistence in SQLite.
- Text extraction for plain text-like files.
- OpenRouter/OpenAI-compatible image multimodal payloads when the selected provider supports vision-style chat message parts.
- ChatGPT-style basic actions: copy, edit user message and resend, retry assistant response, thumbs up/down feedback.
- Simple Markdown table rendering for model replies.
- AI assistant floating bubble moved from External Data Sync home to the Discover Journey home page.

## Notes

- Images are sent as `image_url` content parts for OpenRouter-compatible chat requests. Providers/models without vision support receive text fallback metadata.
- Text-like files are read and included as attachment excerpts. Unsupported binary formats such as PDF are stored and shown, but not parsed into full text in this version.
- Attachments are stored in `ai_assistant_attachments`; original chat history remains in `ai_assistant_messages`.
- Database version bumped to v30.
