# AI Assistant upload/chat UI compile fix

This patch fixes the Flutter compile errors reported in GitHub Actions.

## Root cause

`lib/ai_assistant/ai_assistant_service.dart` referenced attachment helper methods that were not included in the previous package:

- `_persistPendingAttachments`
- `_groupAttachments`
- `_contentWithAttachments`
- `_currentUserMessageForRequest`
- `_imagePartsForAttachments`

## Fix

Implemented the missing helper methods and preserved multimodal `parts` during message deduplication.

The helper methods now:

- persist uploaded attachments into `ai_assistant_attachments`
- read text-like files into `extracted_text`
- attach extracted text to the chat request
- convert image attachments into data URL image parts for OpenRouter/OpenAI-compatible vision models
- group attachments by message ID for request reconstruction
- preserve image parts after message de-duplication

