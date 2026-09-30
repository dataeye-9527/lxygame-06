# 软糖横屏游戏样图 v1

- 日期：2026-09-30
- 生成方式：内置 image_gen 工具。
- 用途：横屏软糖风格概念样图，用于评审材质、布局和信息层级；不代表游戏已实现。
- 规则依据：README 中已确认的四种技能、三发射台、下一发、保留槽与反弹。
- 英文标签仅用于本次样图，产品文案语言仍待确定。
- 输出：[gummy-gameplay-v1.png](gummy-gameplay-v1.png)，1672 × 941。
- 目视检查：四种棋子、四色技能、三个发射台、下一发、保留槽、危险线与反弹预览均有呈现；整体采用软糖与圆润界面。
- 验证边界：棋盘格数、能量条填充比例和反弹几何为概念构图，不能作为代码或物理判定的验收依据；画面尚待用户确认。

## 最终生成提示词

```text
Use case: ui-mockup.
Create ONE polished high-fidelity in-game art-direction sample for an original iOS landscape bubble-shooter puzzle game. Wide 16:9 composition, high resolution, straight-on orthographic full-screen game UI, no phone frame, no surrounding presentation sheet.

STYLE: tactile soft gummy candy, premium playful casual game art, rounded jelly pucks with gently domed faces, broad soft highlights and subtle translucency, soft squashable material; NO glass, crystal, faceted gems, metallic medallions, sugar-grain noise, mascots, characters or faces. Understated lavender background with minimal blurred candy-like curves only at the far margins, muted plum-blue playfield, soft cream and dusty rose rounded UI frames. The gameplay objects dominate, readable at phone size. Restrained ambient shadows and rounded friendly sans-serif type.

LAYOUT: a narrow left sidebar containing EXACTLY FOUR vertically stacked colored skill buttons with small charge meters. Large central rectangular playfield spanning roughly x=18% to 84%, y=12% to 78%. Thin rounded side walls. Upper playfield contains a tightly connected hexagonally staggered cluster of round gummy pucks: roughly twelve per long row, four to five rows, lower edge uneven with a couple of shallow recesses. Every puck must connect through neighbors to the top cluster; no unexplained floating candies. Upper rows dense, lower half of board deliberately open for clear aiming. A thin dashed coral danger line crosses the lower board near y=74%. Three equally spaced distinct rounded candy launcher pedestals aligned beneath it at LEFT, CENTER and RIGHT within the board width. CENTER launcher active with one blue loaded candy and a subtle selection glow; the other two launchers empty and subdued. Exactly three launchers, no fourth.
A delicate dotted aim trajectory travels from the center launcher upward-left to the left playfield wall, bounces ONCE, then travels upward-right and ends in an outlined landing circle immediately below the lower-left surface of the cluster. Geometrically plausible mirrored incident/reflection angles; trajectory never passes through any solid candy. Keep the path clear of the sidebar.
A narrow right utility strip has two distinct compact slots: NEXT showing one red candy, HOLD showing one yellow candy. Small pause button top right.
Compact top HUD: score at top left of main frame; new-row countdown centered above the board.

CANDIES: use ONLY four colors, consistently sized round discs on a hex grid: cyan blue with embossed snowflake, coral red with embossed small burst, golden lemon yellow with embossed double down-chevron, creamy milk white with embossed simple ring. The four shapes have identical round collision silhouettes. Saturated readable bodies with gentle jelly highlights, not blown-out white reflections. White is clearly distinct from blue. Never add purple or green board candy. Tiny embossed symbols are useful identifiers, not faces.
SKILL SIDEBAR: blue snowflake Freeze button with a full charge bar and READY status; red burst Blast button at 12/20; yellow double-down Sweep button at 16/20; white star Wild button at 8/20 and a small x3 badge to explain three future wildcard shots. These are active skill controls, not characters or consumable purchases. Only blue is ready. No effects currently obscuring the board. White wildcard skill icon is a star, while ordinary white board candies have rings.

TEXT, concise and correctly spelled: "SCORE", "1240", "NEW ROW", "00:08", "FREEZE", "READY", "BLAST", "12/20", "SWEEP", "16/20", "WILD", "8/20", "x3", "NEXT", "HOLD". Pause uses an icon. No title or branding, no tutorial paragraphs, no Chinese text, no levels, lives, currency, store, map or marketing copy.
Prioritize a coherent usable gameplay screen, professional spacing, candy material appeal, uncluttered board and immediately legible controls.
```
