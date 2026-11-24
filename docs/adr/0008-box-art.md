# How the box uses stock art

The look is decided in `docs/design.md` "Look". The details in `UI.lua` that are easy to "fix" by mistake:

- The background is `common-dropdown-bg`, placed as `MenuStyle1Mixin` does: 10 outside at the sides, 3 at the top and bottom. Use `SetAtlas` only: the atlas has its own 9-slice data, and explicit slice margins stretch its corners.
- It is drawn twice (sublevels -8 and -7). One layer is 95% opaque in the centre, and bright scenes show through a box this size.
- The search field borders are dimmed to 0.8, so the selected row has the brightest edge.
- The selected row uses the Quick Join card outline (`friends-card-quickJoin-selected`), made for 38px rows (`ROW_H`), blended additively.
- The icon slot is a dark square inside the achievement search icon frame (`search-iconframe-large`), so atlas icons and file icons line up.
- The divider above the status line is the menu divider texture (`MenuVariants.CreateDivider`).
- Gold (`GOLD`) marks typed letters and nothing else.
- The second hint at the right of the status line (Shift-Enter, Space, Drag) is white. In grey it is easy to miss.
