# v0.7 UI 新增素材与生成记录

使用内置 imagegen 生成，所有选用文件已复制进入本工程 assets/ui，原始素材未覆盖。

- assets/ui/title_arena_clean_v01.png：从认可的首页 v02 去除左侧图中文字、按钮与图标，保留实际游戏的圆身主角、恐龙、环绕武器和砂地草丛；作为真实 Godot 控件的无字背景。
- assets/ui/title_logo_ink_v01.png：透明手绘字标，运行时使用 AtlasTexture 和已有 cutout 材质绘制，避免低透明度背景噪点；不覆盖源文件。
- assets/ui/paper_grain_v01.png：空白手绘纸纹，应用在程序绘制的卷轴/羊皮纸轮廓内部。

## 无字背景提示词

Edit the provided approved game title-screen artwork into a CLEAN BACKGROUND PLATE for live Godot UI. Preserve the full 16:9 composition, all right-side arena artwork, EXACT circular egg-body hero with detached circular hands and feet, his six orbiting weapons, the exact cartoon dinosaur silhouettes, sand, grass, tiny stones, XP gems, coins, colors and hand-ink style as closely as possible. The one required edit is to REMOVE ALL text, typography, logo letters, buttons, arrows, save/book/gear icons, keycap and rules from the LEFT dark navy zone, replacing those removed graphics seamlessly with the same uninterrupted subtle midnight-navy paper texture. Keep the organic diagonal ink-cut border between navy UI zone and sandy right art. Do not enlarge or move the character or dinosaurs. Do not invent a gate, human-anatomy caveman, landscape, parchment panel, new props or new text. There must be NO letters, numbers, UI elements, watermarks, calligraphy, logo or tiny marks resembling text anywhere in the result. This is the production background only; functional readable UI will be rendered separately. Matte fully 2D hand-drawn ink illustration. Opaque, preserve original canvas and overall palette.

## 透明字标提示词

Use case: background-extraction / game logo asset. From the supplied approved game UI reference, extract ONLY the exact six-character ivory hand-cut ink game title, stacked on two lines "原始人" then "大作战". Preserve its bold slightly angular cut-paper Chinese lettering, warm ivory fill, small dry-ink edge imperfections, tight typography and exact Chinese spelling. Remove EVERYTHING else, including navy background, red rule, all buttons, all art, all icons and all scenery. The resulting canvas must be genuinely TRANSPARENT with just the isolated opaque warm-ivory letters. Compose the two-line wordmark tightly centered with small transparent margins; approximately a 4:3 asset bounding ratio. No black block behind letters, no shadow, no rectangular paper label, no added text. Production logo asset for the same game UI, not a new title redesign.

## 纸纹提示词

Use case: stylized-concept / production UI texture. Produce ONE flat, edge-to-edge, seamless-looking warm ivory hand-drawn parchment PAPER TEXTURE matching the clean matte parchment surface of the provided approved Chinese game UI reference. Only the empty paper material, no UI. Delicate irregular short paper fibers and very fine dry-ink/paper grain, subtle mottling over a mostly uniform light warm ivory #f1e6cd base. Enough handmade texture to read gently beneath dark navy Chinese UI text at native screen scale. Keep contrast restrained: approximately ivory, pale oat and pale sand, no bright white highlights, no dark stains. Absolutely flat 2D, evenly lit, no 3D lighting, creases, rolled scroll, border, torn edge, letters, pictures, symbols, decorations, heroes, buttons, diagrams or watermark. Fill the whole image with paper; the game code will draw the torn silhouette separately. Do NOT include the sample screen's layout, only study its paper fibers and color.

