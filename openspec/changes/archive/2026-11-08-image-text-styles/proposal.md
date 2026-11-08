# Proposal

## Why

Image markup text is always bold system text with an outline, or a filled label with Option held. The maintainer wants a simple way to style it (2026-11-08): a few fonts, bold and italic, and an effect, in the markup strip. PDF text boxes get the same in a later change, with a strip of their own.

## What Changes

- With Text armed or a text mark selected, the strip shows, beside the size: an Aa menu with the font (System, Serif, Rounded, Mono), Bold and Italic, and the effect: Plain, Outline (today's look, the default), Shadow and Label (a filled rounded box, also chosen by holding Option when placing text, as now). One menu rather than separate controls keeps the strip narrow enough to fit beside the sidebar in a new window.
- The text style is remembered with the rest of the markup style and changes the selected text mark.
- The color stays the markup color.

## Capabilities

### Modified Capabilities

- `image`: markup text has a font, bold, italic and an effect.

## Impact

`ImageMark`'s text case carries a style instead of its label flag (recovery records from earlier development builds with text marks won't restore; there's no release yet); `MarkRenderer` draws the fonts and effects; the strip's text menu (and a palette icon in place of "More…" to save width); the remembered style. Tests for drawing, the style and the strip's width; the image-edit flow checks the text controls show. CHANGELOG; minor version bump.
