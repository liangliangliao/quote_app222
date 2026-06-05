# AI Assistant Discover Bubble Visibility Fix

The AI assistant bubble was already inserted into `lib/pages/discover_page.dart`, but its widget used the full screen `MediaQuery` height to calculate its default position. In the Discover tab, the visible body area is smaller because the page lives above the bottom navigation bar. This could place the bubble off-screen or behind the bottom navigation.

## Fix

`lib/ai_assistant/ai_assistant_bubble.dart` now uses the actual parent `Stack` constraints through `LayoutBuilder` and clamps the saved/default position inside the visible page area.

The default position is now the right side of the Discover page, around 62% of the visible body height, so it should be easy to see on first launch.
