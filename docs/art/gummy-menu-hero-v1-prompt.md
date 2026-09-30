# 软糖菜单焦点插画 v1

- 日期：2026-09-30。
- 生成方式：内置 `image_gen`，`transparent_background: true`。未使用 CLI/API fallback。
- 参考：批准样图、现有炮台、红色棋子，仅作为材质及形态输入。
- 原图：`docs/art/generated-sources/menu_hero-source.png`，1448×1086，真实 RGBA。
- 运行资产：`Resources/Images/menu_hero.png`，640×480。
- 导出：完整画布等比 LANCZOS 缩小，保留原始 alpha，不改绘主体或抠图。
- alpha≥16 的实体边界、校验值及统计见 `asset-manifest.json`。
- 用途：开始页左侧独立焦点插画，四色压印软糖与一个奶油粉色炮台形成集中构图；透明底，不含界面、按钮或文字。
- 原有棋子、炮台、背景、万能星素材继续复用。按钮与可伸缩面板由程序绘制，避免将整张 UI 烘焙成不可交互的背景。
- 目视验收：蓝雪花、红爆裂、黄双下箭头、白环均清楚；软糖材质与现有棋子一致；炮台完整，无人物或额外游戏系统元素。实际界面验收另见 QA 记录。
- 透明边缘检查：运行图在 alpha≥16 时只有三块主体连通区域（炮台及蓝红、黄、白），无孤立噪点；alpha≥8 时额外五个单像素，最大 alpha 为 12/255。黑底放大预览可显露低 alpha 彩色边缘，未手动删除，实际淡紫背景小尺寸需结合首屏截图判断。

## 最终提示词

```text
Use case: stylized-concept.
Asset type: one transparent focal illustration for the HOME page of an interactive iOS soft-gummy bubble shooter, not a screenshot, not a complete UI.
Input images: Image 1 docs/art/gummy-gameplay-v1.png is ONLY the approved overall style, palette and material reference; Image 2 Resources/Images/cannon.png is a precise launcher design reference; Image 3 Resources/Images/gummy_red.png is a token finish and symbol reference.
Primary request: create a polished compact composition celebrating the actual gameplay objects: ONE cream-ivory rounded candy cannon with a dusty pink oval pedestal in the lower center, its broad circular mauve barrel angled upward/front, and a small buoyant arc of FOUR identical-size round soft gummy tokens above it. Exactly one cyan blue token with embossed snowflake, one coral red token with embossed eight-spoke burst, one golden yellow token with embossed stacked double down-chevron, one milk-white token with embossed ring. Match reference cannon shape and the domed token style. A blue token sits nearest the barrel as though about to be fired; other three float in a gentle balanced arc. Tokens have no faces.
Style/medium: premium tactile 3D casual puzzle game artwork; plump soft jelly candy, gentle upper-left highlights, readable broad cream-tinted embossed symbols and clean rounded silhouettes. Cohesive restrained shadows within the objects.
Composition/framing: landscape 4:3 canvas, compact centered composition completely inside image with at least 8 percent transparent margin on every edge. Entire cannon pedestal visible; upper candies spaced enough for distinct silhouettes. Composition to fit a 470x353 point menu area, slightly larger tokens than barrel opening, no UI card or framing behind it.
Color palette: approved lavender environment will be added by app; object colors limited to cyan, coral, gold, milk-cream and dusty pink/mauve cannon details. No purple or green tokens.
Background: genuinely transparent alpha, no solid backdrop or baked checkerboard, no ground plane, no external cast shadow, no decorative cloud shape.
Constraints: no text, logo, letters, buttons, panels, border, sparkles, coins, levels, arrows outside the token emblems, mascots, characters or extra props. Do not change to glass, crystal, plastic toy, mechanical/metallic cannon. A SINGLE isolated composite asset with real alpha.
```
