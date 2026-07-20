# Portrait presentation contract

Character source art may remain square or vertical, but every player-facing portrait surface uses the same presentation rules:

- Portrait cards and detail headers receive a square crop through `PortraitPresentation.normalize()`.
- Vertical art uses an upper-body focus at 36% of source height so faces, weapons, and role silhouettes remain readable.
- Near-square art is preserved without resampling or destructive source edits.
- Runtime controls own framing, clipping, warmth, hover scale, and surrounding gothic matte treatment.
- Combat actors keep the complete source silhouette; their readability comes from team rims, ground shadows, and health/team markers rather than portrait cropping.

This keeps source assets lossless while making shop, roster, starter-selection, and detail-panel portraits consistent across viewport sizes.
