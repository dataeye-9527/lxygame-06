# 软糖原型独立素材生成记录

- 日期：2026-09-30。
- 模式：内置 `image_gen`；未使用 CLI/API fallback 或第三方付费服务。
- 参考输入：`docs/art/gummy-gameplay-v1.png`，仅用于材质、颜色与形状，不用作运行界面。
- 透明设置：四棋子、炮台、万能星为 `transparent_background: true`；背景为 `false`。
- 原始输出留存：`docs/art/generated-sources/`；运行纹理：`Resources/Images/`。
- 导出仅机械裁去透明边缘、等比缩小与居中填充，保留生成的主体、符号与 alpha；裁切依据 alpha ≥16 的实体边界，原图完整留存。
- 四棋子画布 256×256，实体最大径 230（约90%），高光均来自左上。炮台 320×280，星 128×128，背景 1200×680。
- 运行实现使用独立 SpriteKit 节点；文字、技能状态、控件、瞄准线、棋盘边框和光环由程序绘制。
- 资源 manifest：`docs/art/asset-manifest.json`。

## blue

Use case: stylized-concept. Asset type: transparent individual SpriteKit game piece. Input image 1 is ONLY a style reference: approved landscape gummy bubble game concept. Generate ONE circular BLUE gummy token matching the blue pieces in that reference, not a screenshot or UI. Bright cyan blue soft translucent jelly, rounded plump disk, subtle upper-left glossy highlight and darker blue rim, a bold embossed pale-cyan six-arm snowflake centered on face. Straight-on front view, perfectly circular silhouette; symbol broad and simplified to stay recognizable when the final token is 23 screen pixels wide on a dense 18-column board. The SINGLE token is centered and occupies 90 percent of a square image, consistent circle geometry and visual center. Actual transparent alpha background; no backdrop, no checkerboard, no ground plane, no external cast shadow, no text, no frame, no other objects, no panels or interface. Preserve the approved soft rounded candy look.

## red

Use case: stylized-concept. Asset type: transparent individual SpriteKit game piece. Input image 1 is ONLY a style reference: approved landscape gummy bubble game concept. Generate ONE circular coral RED gummy token matching its corresponding piece in the reference, not a screenshot or UI. warm red-coral jelly with a darker red rim, rounded plump disk, restrained upper-left glossy highlight, bold embossed pale-pink radial burst made of eight short rounded spokes around a small empty center. Straight-on front view, perfectly circular silhouette, front symbol bold and simplified to stay recognizable when final token is 23 screen pixels wide on a dense 18-column board. The SINGLE token centered, occupies 90 percent of a square image. Actual transparent alpha background; no backdrop, no checkerboard, no ground plane, no external cast shadow, no text, no frame, no other objects, no panels or interface. Preserve the approved soft rounded candy look and simple face emblem.

## yellow

Use case: stylized-concept. Asset type: transparent individual SpriteKit game piece. Input image 1 is ONLY a style reference: approved landscape gummy bubble game concept. Generate ONE circular golden YELLOW gummy token matching its corresponding piece in the reference, not a screenshot or UI. golden yellow jelly with a warm amber rim, rounded plump disk, restrained upper-left glossy highlight, bold embossed pale-cream TWO DOWNWARD CHEVRONS, stacked vertically, broad rounded V shapes pointing downward. Straight-on front view, perfectly circular silhouette, front symbol bold and simplified to stay recognizable when final token is 23 screen pixels wide on a dense 18-column board. The SINGLE token centered, occupies 90 percent of a square image. Actual transparent alpha background; no backdrop, no checkerboard, no ground plane, no external cast shadow, no text, no frame, no other objects, no panels or interface. Preserve the approved soft rounded candy look and simple face emblem.

## white

Use case: stylized-concept. Asset type: transparent individual SpriteKit game piece. Input image 1 is ONLY a style reference: approved landscape gummy bubble game concept. Generate ONE circular creamy WHITE gummy token matching its corresponding piece in the reference, not a screenshot or UI. opaque warm milk-white gummy with pale pink-beige shaded rim, rounded plump disk, restrained upper-left glossy highlight, one bold embossed ivory circular RING centered on the face. Straight-on front view, perfectly circular silhouette, front symbol bold and simplified to stay recognizable when final token is 23 screen pixels wide on a dense 18-column board. The SINGLE token centered, occupies 90 percent of a square image. Actual transparent alpha background; no backdrop, no checkerboard, no ground plane, no external cast shadow, no text, no frame, no other objects, no panels or interface. Preserve the approved soft rounded candy look and simple face emblem.

## wild

Use case: stylized-concept. Asset type: transparent wildcard overlay icon for gummy puzzle game. Image 1 only style reference. Generate ONE small cream ivory five-point STAR emblem matching the star in bottom-left WILD icon of the reference. Plump softly rounded star with gently beveled embossed edges, soft upper-left highlight and pale rosy shading, straight-on view, no disk or button under it. Centered single star takes 84 percent of square canvas, clear broad shape recognizable at 20 screen pixels, genuine transparent alpha background. No external shadow, no backdrop, no checkerboard, no text, no other objects, no interface.

## cannon

Use case: stylized-concept. Asset type: transparent SpriteKit game launcher sprite. Image 1 is ONLY a style reference, approved landscape gummy game. Generate ONE complete candy launcher matching the bottom left and right launchers in reference: creamy ivory rounded doughnut-like upright barrel with a dark mauve circular opening angled slightly upward toward viewer, seated on a short pink rounded oval pedestal, straight frontal composition, symmetry about vertical center. No projectile or token in opening. Three-quarter top view enough to see the round opening and thick soft barrel wall, upper-left restrained highlight, candy smooth gummy/cream material. Single isolated launcher occupies 90 percent of a roughly square canvas, actual transparent alpha background, no backdrop, checkerboard, ground plane or cast shadow outside object. No glowing ring (active state rendered by app), no text, no controls, no game board, no extra pieces. Sprite displayed approx 118 by 100 points; simple broad silhouette and colors.

## background

Use case: stylized-concept. Asset type: landscape background texture only for an interactive SpriteKit gummy bubble game. Image 1 ONLY style reference. Generate soft pastel lavender background matching ONLY the outer environment behind the UI in the reference: a delicate low-contrast lavender/mauve gradient with softly blurred out-of-focus rounded gummy candies partially cropped at extreme corners. Very sparse decorations confined to outer 8 percent of frame; majority including center stays plain low contrast lavender. Landscape 1200:680 ratio. Keep colors gentle, avoid visual noise, smooth candy dream-like studio lighting. No text, no panels, no buttons, no board, no tokens arranged in a grid, no cannon, no UI, no logo, no character, no coin, no map. This will sit underneath fully interactive separately drawn UI, so absolutely do not reproduce interface from reference.
