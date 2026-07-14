#!/usr/bin/env python3
"""
generate.py — App Store 截图占位生成器

为 iPhone 6.5"（1242 × 2688）生成 10 张 PNG 占位截图：
  en-US/iPhone6.5/01_login.png         02_feed.png          03_compose.png
                   04_notifications.png 05_profile.png
  zh-Hans/iPhone6.5/ 同上 5 张

⚠️ 重要：本脚本生成的截图是「占位用」，真实上架前请用真实 App 截图替换。
   跑法：python3 generate.py
   依赖：仅用 Python 3 标准库 + Pillow（PIL），无需 ImageMagick。
"""

from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

# --- iPhone 6.5" 尺寸 ---------------------------------------------------
W, H = 1242, 2688

# --- 颜色（取自 client/lib/theme/app_colors.dart light 主题）--------------
BG          = (255, 255, 255)        # background
SURFACE     = (239, 239, 239)        # surface
SURFACE2    = (245, 245, 245)        # surfaceSecondary
DIVIDER     = (239, 239, 239)
BORDER      = (208, 208, 208)
TEXT        = (0, 0, 0)              # textPrimary
TEXT2       = (102, 102, 102)        # textSecondary
TEXT_MUTED  = (153, 153, 153)        # textMuted
ACCENT      = (0, 100, 224)          # accent
LIKE        = (255, 0, 0)            # like
REPOST      = (0, 128, 0)            # repost
PHONE_FRAME = (24, 24, 24)           # iPhone 机身

# --- 字体（用 PIL 默认字体；macOS 自带字体足够清晰）-----------------------
def get_font(size: int) -> ImageFont.FreeTypeFont:
    """优先尝试 macOS 系统字体；找不到退回 PIL 默认"""
    for path in [
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/SFNSDisplay.ttf",
        "/Library/Fonts/Arial.ttf",
    ]:
        try:
            return ImageFont.truetype(path, size)
        except (OSError, FileNotFoundError):
            continue
    return ImageFont.load_default()

# --- 工具函数 -----------------------------------------------------------
def rounded_rect(draw, xy, radius, fill, outline=None, width=1):
    """画圆角矩形"""
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)

def text_w(draw, s: str, font) -> int:
    """用 textbbox 估算文字宽度，兼容新旧 PIL"""
    try:
        l, t, r, b = draw.textbbox((0, 0), s, font=font)
        return r - l
    except AttributeError:
        return draw.textlength(s, font=font)

def draw_text(draw, pos, s, font, fill=TEXT):
    draw.text(pos, s, font=font, fill=fill)

def draw_status_bar(img):
    """iPhone 顶部状态栏：时间 + 信号 + 电池"""
    d = ImageDraw.Draw(img)
    f = get_font(36)
    # 时间（左侧）
    draw_text(d, (60, 30), "9:41", f, TEXT)
    # 信号 + Wi-Fi + 电池（右侧）
    draw_text(d, (W - 250, 30), "●●●●  Wi-Fi  🔋", f, TEXT)

def draw_tab_bar(img, active_idx=0):
    """iPhone 底部 Tab Bar：5 个图标（Feed/Search/Compose/Notify/Profile）"""
    d = ImageDraw.Draw(img)
    tab_h = 180
    y0 = H - tab_h
    rounded_rect(d, (40, y0, W - 40, H - 50), 32, SURFACE2)

    labels = ["Feed", "Search", "Post", "Notify", "Me"]
    n = 5
    slot_w = (W - 80) / n
    f = get_font(32)
    for i, label in enumerate(labels):
        cx = 40 + slot_w * i + slot_w / 2
        # 圆点占位
        d.ellipse([cx - 24, y0 + 30, cx + 24, y0 + 78],
                  fill=ACCENT if i == active_idx else TEXT_MUTED)
        # 标签
        lw = text_w(d, label, f)
        draw_text(d, (cx - lw / 2, y0 + 100), label, f,
                  ACCENT if i == active_idx else TEXT2)

# --- 截图模板 -----------------------------------------------------------
def base_canvas() -> Image.Image:
    img = Image.new("RGB", (W, H), PHONE_FRAME)
    d = ImageDraw.Draw(img)
    # 屏幕区域（圆角）
    rounded_rect(d, (20, 20, W - 20, H - 20), 80, BG)
    # 把屏幕区域裁出来作为后续绘制底
    screen = img.crop((20, 20, W - 20, H - 20))
    return screen

def save_screen(screen_img, path):
    """把屏幕区域贴回带 iPhone 框的画布并保存"""
    canvas = Image.new("RGB", (W, H), PHONE_FRAME)
    d = ImageDraw.Draw(canvas)
    rounded_rect(d, (20, 20, W - 20, H - 20), 80, BG)
    canvas.paste(screen_img, (20, 20))
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path, "PNG", optimize=True)

# =========================================================================
# 场景 1：登录页（01_login.png）
# =========================================================================
def render_login(lang: str, out_path: str):
    screen = base_canvas()
    d = ImageDraw.Draw(screen)

    draw_status_bar(screen)
    # 主标题
    f_h1 = get_font(96)
    title = "Tweet" if lang == "en" else "Tweet"
    draw_text(d, (W/2 - text_w(d, title, f_h1)/2, 400), title, f_h1, TEXT)

    # 副标题
    f_sub = get_font(48)
    sub = "Sign in to continue" if lang == "en" else "登录以继续"
    draw_text(d, (W/2 - text_w(d, sub, f_sub)/2, 540), sub, f_sub, TEXT2)

    # 4 个登录按钮（占位）
    btn_x0, btn_x1 = 120, W - 120
    btn_y = 900
    btn_h = 140
    gap = 200
    f_btn = get_font(44)

    buttons = [
        ("Continue with Apple",  TEXT, SURFACE,    None),
        ("Continue with Google", TEXT, SURFACE,    None),
        ("Use phone number",     TEXT, SURFACE,    None),
        ("Use username",         TEXT, SURFACE,    None),
    ] if lang == "en" else [
        ("通过 Apple 继续",       TEXT, SURFACE,    None),
        ("通过 Google 继续",     TEXT, SURFACE,    None),
        ("使用手机号登录",         TEXT, SURFACE,    None),
        ("使用用户名登录",         TEXT, SURFACE,    None),
    ]
    for i, (label, color, fill, _) in enumerate(buttons):
        y = btn_y + i * gap
        rounded_rect(d, (btn_x0, y, btn_x1, y + btn_h), 24, fill, BORDER, 2)
        draw_text(d, (W/2 - text_w(d, label, f_btn)/2, y + 38), label, f_btn, color)

    # 底部占位文案
    f_footer = get_font(36)
    footer = "By continuing you agree to our Terms & Privacy Policy." if lang == "en" \
             else "继续即代表你同意我们的服务条款与隐私政策。"
    draw_text(d, (W/2 - text_w(d, footer, f_footer)/2, H - 200), footer, f_footer, TEXT_MUTED)

    save_screen(screen, out_path)

# =========================================================================
# 场景 2：首页 Feed（02_feed.png）
# =========================================================================
def render_feed(lang: str, out_path: str):
    screen = base_canvas()
    d = ImageDraw.Draw(screen)

    draw_status_bar(screen)

    # 顶部标题栏
    f_h1 = get_font(72)
    title = "Home" if lang == "en" else "首页"
    draw_text(d, (80, 110), title, f_h1, TEXT)

    # Feed 内容：3 个帖子卡片
    f_user = get_font(48)
    f_body = get_font(40)
    f_meta = get_font(32)

    posts = [
        ("@alice",  "Just shipped a new feature! 🚀 #buildinpublic",
         "2h", False, False),
        ("@bob",    "Anyone else feel like notifications never stop?",
         "5h", True, False),
        ("@charlie", "Coffee + code = ❤️",
         "1d", False, True),
    ] if lang == "en" else [
        ("@alice",  "刚刚发版了一个新功能！🚀 #buildinpublic",
         "2小时前", False, False),
        ("@bob",    "有没有人也觉得通知永远停不下来？",
         "5小时前", True, False),
        ("@charlie", "咖啡 + 代码 = ❤️",
         "1天前",  False, True),
    ]

    y = 260
    for user, body, time, liked, reposted in posts:
        # 卡片背景
        rounded_rect(d, (60, y, W - 60, y + 460), 20, SURFACE2)
        # 头像
        d.ellipse([100, y + 40, 180, y + 120], fill=ACCENT)
        # 用户名
        draw_text(d, (210, y + 50), user, f_user, TEXT)
        # 时间
        draw_text(d, (W - 220, y + 60), time, f_meta, TEXT_MUTED)
        # 正文
        # 简单换行
        words = body.split(" ")
        line = ""
        ly = y + 150
        for w in words:
            test = (line + " " + w).strip()
            if text_w(d, test, f_body) > W - 280:
                draw_text(d, (100, ly), line, f_body, TEXT)
                ly += 60
                line = w
            else:
                line = test
        if line:
            draw_text(d, (100, ly), line, f_body, TEXT)
        # 互动图标（占位）
        ix = 100
        for icon, color, filled in [("♡", LIKE, liked), ("↻", REPOST, reposted), ("💬", TEXT2, False)]:
            d.ellipse([ix, ly + 80, ix + 36, ly + 116], fill=color if filled else TEXT_MUTED)
            ix += 100

        y += 500

    draw_tab_bar(screen, active_idx=0)
    save_screen(screen, out_path)

# =========================================================================
# 场景 3：发帖（03_compose.png）
# =========================================================================
def render_compose(lang: str, out_path: str):
    screen = base_canvas()
    d = ImageDraw.Draw(screen)

    draw_status_bar(screen)

    # 顶部：取消 + 发布按钮
    f_top = get_font(48)
    cancel = "Cancel" if lang == "en" else "取消"
    draw_text(d, (80, 130), cancel, f_top, TEXT2)
    post = "Post" if lang == "en" else "发布"
    # 发布按钮
    rounded_rect(d, (W - 240, 120, W - 80, 200), 20, ACCENT)
    draw_text(d, (W - 160 - text_w(d, post, f_top)/2, 140), post, f_top, BG)

    # 用户信息
    d.ellipse([100, 280, 180, 360], fill=ACCENT)
    f_user = get_font(48)
    username = "@you" if lang == "en" else "@你"
    draw_text(d, (210, 290), username, f_user, TEXT)

    # 多行输入占位
    f_hint = get_font(56)
    hint = "What's happening?" if lang == "en" else "在想什么？"
    draw_text(d, (100, 480), hint, f_hint, TEXT_MUTED)
    # 横线（光标）
    d.line([(100, 600), (W - 100, 600)], fill=DIVIDER, width=4)

    # 附件按钮
    f_attach = get_font(44)
    attaches = [
        ("📷  Photo"),
        ("📍  Location"),
        ("📊  Poll"),
    ] if lang == "en" else [
        ("📷  照片"),
        ("📍  位置"),
        ("📊  投票"),
    ]
    y = 1600
    for a in attaches:
        d.ellipse([110, y + 12, 150, y + 52], fill=TEXT2)
        draw_text(d, (180, y), a, f_attach, TEXT)
        y += 120

    draw_tab_bar(screen, active_idx=2)
    save_screen(screen, out_path)

# =========================================================================
# 场景 4：通知（04_notifications.png）
# =========================================================================
def render_notifications(lang: str, out_path: str):
    screen = base_canvas()
    d = ImageDraw.Draw(screen)

    draw_status_bar(screen)
    f_h1 = get_font(72)
    title = "Notifications" if lang == "en" else "通知"
    draw_text(d, (80, 110), title, f_h1, TEXT)

    # 通知列表
    f_body = get_font(44)
    f_time = get_font(32)

    items = [
        ("@alice",  "liked your post",         "2m",  LIKE),
        ("@bob",    "replied: \"me too!\"",   "10m", REPOST),
        ("@charlie","followed you",            "1h",  ACCENT),
        ("@dave",   "mentioned you in a post", "3h",  TEXT2),
        ("@eve",    "and 12 others liked your post", "5h", LIKE),
    ] if lang == "en" else [
        ("@alice",  "赞了你的帖子",            "2分钟前",  LIKE),
        ("@bob",    "回复了你：「我也是！」",   "10分钟前", REPOST),
        ("@charlie","关注了你",                "1小时前",  ACCENT),
        ("@dave",   "在帖子中提及了你",        "3小时前",  TEXT2),
        ("@eve",    "其他 12 人也赞了你的帖子", "5小时前",  LIKE),
    ]

    y = 280
    for user, action, time, color in items:
        # 头像
        d.ellipse([90, y + 20, 170, y + 100], fill=color)
        # 文字
        draw_text(d, (200, y + 20), user, f_body, TEXT)
        draw_text(d, (200, y + 80), action, f_body, TEXT2)
        draw_text(d, (W - 240, y + 40), time, f_time, TEXT_MUTED)
        # 分隔线
        d.line([(80, y + 180), (W - 80, y + 180)], fill=DIVIDER, width=2)
        y += 200

    draw_tab_bar(screen, active_idx=3)
    save_screen(screen, out_path)

# =========================================================================
# 场景 5：个人主页（05_profile.png）
# =========================================================================
def render_profile(lang: str, out_path: str):
    screen = base_canvas()
    d = ImageDraw.Draw(screen)

    draw_status_bar(screen)

    # 顶部：大头像 + 资料
    d.ellipse([100, 200, 280, 380], fill=ACCENT)
    f_name = get_font(64)
    f_bio = get_font(40)
    f_meta = get_font(36)

    display = "Your Name" if lang == "en" else "你的昵称"
    username = "@you"
    bio = "Building Tweet — a focused social app." if lang == "en" \
          else "正在打造 Tweet —— 一款专注的社交应用。"
    posts_count = "127" if lang == "en" else "127"
    followers = "1.2k" if lang == "en" else "1200"
    following = "342" if lang == "en" else "342"

    draw_text(d, (320, 220), display, f_name, TEXT)
    draw_text(d, (320, 310), username, f_meta, TEXT2)
    draw_text(d, (320, 370), bio, f_bio, TEXT)

    # 数据行：Posts / Followers / Following
    stats = [(posts_count, "Posts" if lang == "en" else "帖子"),
             (followers,   "Followers" if lang == "en" else "关注者"),
             (following,   "Following" if lang == "en" else "正在关注")]
    sx = 100
    for val, lab in stats:
        draw_text(d, (sx, 510), val, f_name, TEXT)
        lw = text_w(d, lab, f_meta)
        draw_text(d, (sx, 590), lab, f_meta, TEXT2)
        sx += 400

    # 3 个帖子网格（占位方块）
    grid_y = 720
    cell = 360
    gap = 24
    for row in range(3):
        for col in range(3):
            x = 60 + col * (cell + gap)
            y = grid_y + row * (cell + gap)
            rounded_rect(d, (x, y, x + cell, y + cell), 16, SURFACE)

    draw_tab_bar(screen, active_idx=4)
    save_screen(screen, out_path)

# =========================================================================
# 主入口
# =========================================================================
SCENES = [
    ("01_login.png",         render_login),
    ("02_feed.png",          render_feed),
    ("03_compose.png",       render_compose),
    ("04_notifications.png", render_notifications),
    ("05_profile.png",       render_profile),
]

LANGS = [
    ("en-US",   "en"),
    ("zh-Hans", "zh"),
]

OUT_ROOT = Path(__file__).resolve().parent

def main():
    for lang_dir, lang_code in LANGS:
        for fname, fn in SCENES:
            out = OUT_ROOT / lang_dir / "iPhone6.5" / fname
            fn(lang_code, str(out))
            print(f"  ✓ {out.relative_to(OUT_ROOT.parent.parent.parent)}")
    print(f"\nDone. {len(SCENES) * len(LANGS)} screenshots generated.")

if __name__ == "__main__":
    main()
