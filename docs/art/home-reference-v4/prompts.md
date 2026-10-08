# 主页参考图复刻素材

2026-10-08。以用户最新提供的 Gummy Ricochet 双模式主页为参考，使用内置 `image_gen` 生成六个主页资产，后按用户追加要求补充一张通用面板，将美术风格延伸至其他页面；未使用 CLI/API fallback。标题保持 GUMMY RICOCHET。图片原样复制至 `Resources/Assets.xcassets/home_*_v4.imageset/` 和 `candy_panel_v4.imageset/`，保留 alpha；按钮图集由 SpriteKit 子纹理分开拼接，运行时文字、图标及数据由程序绘制。尺寸与 SHA-256 见 `asset-manifest.json`。

## 最终提示词

### 通用奶油面板

```text
Use case: stylized-concept. Asset type: production UI skin for the iOS game Gummy Ricochet, matching the supplied reference image. The reference image is style reference only. Generate ONE blank square rounded rectangular cream candy panel for reusable 9-slice rendering across settings, level select, leaderboard, game HUD and pause/result dialogs. High-polish glossy tactile 3D casual candy game materials, warm ivory clean flat empty central face, pastel peach inset outline, thick creamy white raised bevel rim, delicate pink underside shadow, bright curved white reflections near top corners, subtle cream frosting wave only near upper interior edge. Square front-facing orthographic panel, 1:1 canvas. Symmetric broad straight middle on each edge, corners radius around 12 percent of width. Panel fills 96 percent of canvas, transparent 2 percent margin. Border thickness around 3 percent of width. Center and middle edges must be unobstructed, consistent, smoothly stretchable; keep decorative highlights entirely in corner areas for 9-slice scaling. Pale flat central ivory fill, no noisy texture. Real transparent alpha outside panel; opaque cream inside. NO text, symbols, buttons, candies, stars, characters, scenery or watermark. Match the cream shell and shiny lighting of ENDLESS and LEVELS panels in the reference precisely.
```

### background

```text
Use case: stylized-concept. Asset type: full-bleed 16:9 landscape background layer for the reference iOS candy game's home screen. Image 1 is the exact user's visual reference.
Recreate ONLY the environment behind the interface: dreamy lavender-pink candy landscape with rich pastel-vivid palette, pink icing mountains at outer edges, cyan candy-waterfall at far left, pastel lavender sky with soft pink clouds and tiny bokeh lights, glossy cyan/pink jelly beans floating near upper outer edges, a pink pastel rainbow centered low in distance, blue-pink shiny candy liquid ground with sweeping cream reflections, shiny plump blurred pink/purple/yellow foreground jelly candies along bottom corners. Match the reference camera, soft atmospheric depth, high-polish 3D casual game art, glowing cream white highlights, soft magical pink lighting.
Composition: reproduce environment composition closely, leave middle broadly softly blurred and clear to place separate logo/hero/menu layers; foreground edge candies only at bottom corners. Do not draw ANY UI or focal objects: NO logo, text, cannon, machine, skill discs, score plaque, hero pedestal, panels or buttons. Canvas exactly wide 16:9. No characters or watermark.
```

### logo

```text
Use case: logo-brand. Asset type: transparent title layer for the iOS candy-game homepage. Image 1 is the exact target title to recreate.
Faithfully recreate the complete upper-left title plaque from the reference reading EXACTLY "GUMMY" on the first row and "RICOCHET" on the second row. Same letter shapes, arrangement, scale balance, plump glossy domed hot-pink top letters and bright purple bottom letters, creamy pale rim, berry/purple shaded embossed edges and broad white specular gleams. Same irregular cream plaque behind lettering with glossy candy-pink and lavender scalloped rim and small golden five-point stars near left edge and upper right. Bottom RICOCHET word spans essentially same width as top GUMMY.
Composition: isolate only this complete title plaque, straight-on view, landscape 2:1 canvas, tightly frame entire title with 2 percent transparent margin, no cropped parts. Genuinely transparent alpha around plaque. Spell G U M M Y and R I C O C H E T exactly. No other objects, text, backdrop, characters or interface.
```

### hero

```text
Use case: stylized-concept. Asset type: transparent hero illustration layer for the LEFT LOWER half of an iOS candy-game homepage. Image 1 is the exact user's reference. Recreate the launcher, four floating tokens and candy podium under the title, no logo or background.
A cream-ivory very rounded open cannon with pink recessed opening tilted upward toward viewer, glossy pink base. Exactly FOUR large plump round glossy gummy tokens floating above: red with cream eight-spoke burst top center, yellow with embossed double down-chevron left middle, ivory with embossed circular ring right middle, cyan with embossed white snowflake lower center immediately over cannon mouth. Reference sizes and arrangement precisely. Tiny pale star sparkles between tokens, two small golden stars along outside.
Cannon sits on a broad short cylindrical candy-cake podium with cream melted icing along top edge, pink-lilac ribbed sidewall, glossy multicolor little jelly candies scattered at its edges. On podium front, a horizontal plump cream capsule BEST SCORE plaque with one small golden crown at left; CENTRAL AND RIGHT TEXT AREA COMPLETELY BLANK so app will add dynamic BEST and number. Reference cream/pink shiny tactile materials and golden highlights. No text baked into image.
Composition: square 1:1 canvas, center full object, broad podium across lower quarter, four tokens fill top half, maintain 3 percent transparent margin around entire silhouette. Real transparent alpha around and between objects. No floor outside podium, no landscape, no logo, no words, letters, numbers, UI buttons or characters.
```

### card

```text
Use case: stylized-concept. Asset type: one reusable transparent blank cream candy card shell for the RIGHT home-menu cards in an iOS game. Image 1 is the user's exact reference.
Recreate ONLY the cream rounded rectangular board behind the reference ENDLESS or LEVELS section, with NO text, icons, stars or buttons. Wide pill-rounded rectangular shell with a broad straight middle, glossy cream beveled outer edge, delicate peach inset rim, warm ivory and pale peach face, scalloped soft white frosting glaze near upper portion, gentle warm pink drop shadow under bottom lip. Match reference proportion and material. The entire central face is clean empty ivory/peach for live title, supporting text and separately composed buttons.
Composition: wide 5:2 canvas, shell nearly fills frame with only 2 percent transparent padding. Orthographic front view, no skew. Genuinely transparent alpha outside shell. No purple frame, no text, no candy pieces, no icons, no stars, no buttons, no background.
```

### buttons

```text
Use case: stylized-concept. Asset type: ONE transparent UI sprite-sheet atlas of three blank glossy candy button skins for an iOS game. Image 1 is the exact style reference.
Square canvas divided into exactly THREE equal horizontal rows. In row 1 centered at y=1/6, one wide bright cyan-blue pill button matching New Game; row 2 centered at y=1/2, one wide vivid lavender-purple pill matching Resume; row 3 centered at y=5/6, one wide golden-honey-yellow pill matching Select Level. Each button has same width 90 percent of canvas and height 24 percent of canvas, so all three have wide 3.75:1 pill proportions. 5 percent transparent left/right padding, clean large transparent gaps between rows. Same cream white bright outer outline, layered color bevel rim, glossy plump bright jelly faces, broad curved white highlights near top corners, soft shaded lower edge and tiny bubble-like gleams along bottom. Cyan needs strong bright saturated sky-blue, lavender rich luminous light purple, yellow bright cream-gold. NO text, NO icons, NO symbols, NO decorative stars. Each is one solid empty pill surface reserved for live icon and label.
Real transparent alpha outside each separate button. Strict three evenly spaced rows, no touching objects, no background, grid lines or labels.
```

### footer

```text
Use case: stylized-concept. Asset type: ONE transparent UI sprite-sheet atlas of three small utility candy button skins for an iOS game. Image 1 is the exact style reference.
Square canvas divided into exactly THREE equal horizontal rows. At first row center y=1/6 place one pastel lavender pill matching Local Scores; second row y=1/2 one pastel pink pill matching Settings; third row y=5/6 one warm cream-ivory pill matching Help. All buttons equal width 90 percent of canvas and equal height 24 percent of canvas, wide 3.75:1 pill proportions. Exactly 5 percent transparent left/right margin and large clear transparent gaps between rows. Match reference polished cream-white raised outer rims, fine colored inset edge, softly inflated jelly faces with faint broad white gloss across upper left, gentle shaded bottom lip. Lighter and subtler than main play buttons.
Skins only, NO words, NO icons, NO symbols. Genuine transparent alpha outside each button. Three clean separate evenly spaced rows, no grid or background.
```
