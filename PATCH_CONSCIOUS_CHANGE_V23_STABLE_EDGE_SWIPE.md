# Conscious Change v23 - Stable edge swipe

- Reworked section reader edge-swipe behavior so failed page-turn attempts only animate the outer page back.
- Removed high-frequency `jumpTo`/scroll pinning paths during page-turn attempts.
- Preloads previous/current/next section pages as independent full-screen layers.
- Drag updates now only update an outer `ValueNotifier` offset; current text and `ScrollView` are not rebuilt each frame.
- Preview pages are fixed read-only layers from initial top position.
- Disabled overscroll indicator in the reader to avoid edge-glow flicker during page-turn attempts.
