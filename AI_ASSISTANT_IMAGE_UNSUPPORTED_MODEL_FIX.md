# AI Assistant Image Unsupported Model Fix

## Problem

Some selected chat models are text-only even when they are reached through a platform that also has multimodal models.

Observed errors:

- DeepSeek `deepseek-v4-pro` rejected `image_url` message parts:
  `unknown variant image_url, expected text`
- OpenRouter `minimax/minimax-m2.5` rejected image input:
  `No endpoints found that support image input`

## Fix

The assistant now gates image parts by the actual selected provider/model capability instead of assuming every model under OpenRouter/EdenAI/DeepSeek supports images.

### Changes

- DeepSeek: never sends OpenAI-style `image_url` parts.
- OpenRouter: sends `image_url` only for models that look multimodal, such as GPT-4o/GPT-4.1/GPT-5, Gemini, Claude, Qwen-VL, Pixtral, LLaVA, InternVL, Gemma 3, etc.
- OpenAI: sends image parts only for likely vision-capable models.
- Eden AI: keeps multimodal enabled for OpenAI/GPT-style multimodal selections.
- Unsupported models fall back to plain text attachment descriptions and any locally extracted file text, so the chat request no longer crashes.

## Notes

If a user selects a text-only model, the model cannot truly inspect the image pixels. It can only see the attachment name/metadata and extracted text from non-image files. To analyze image content, select a vision-capable model.
