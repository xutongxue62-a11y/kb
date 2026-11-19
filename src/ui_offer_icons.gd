extends RefCounted
## Small, painted inventory symbols. The same art is used in camp and rewards.

const DRAWINGS := {
    "heal": '<path d="M9 48L45 58L53 48L14 39Z" fill="#936043"/><path d="M51 47L17 58L11 50L45 38Z" fill="#aa7952"/><path d="M31 5C25 17 37 22 24 30C20 27 18 23 19 20C6 34 16 48 31 47C49 48 55 30 43 21C44 28 39 31 36 31C41 22 40 15 31 5Z" fill="#c86645"/><path d="M31 25C31 33 21 35 24 42C28 47 38 45 39 39C39 34 35 31 31 25Z" fill="#f1bd68"/>',
    "vitality": '<path d="M32 56C22 49 6 37 6 23C5 8 22 4 31 17C40 3 58 8 58 23C58 38 43 49 32 56Z" fill="#be694f"/><path d="M11 24C10 15 20 12 24 18" fill="none" stroke="#eab395"/><path d="M32 24V44M22 34H42" fill="none" stroke="#f5ddb0" stroke-width="5"/>',
    "explorer": '<path d="M17 18C16 8 24 7 36 9L46 14L43 20" fill="none" stroke="#704c36" stroke-width="5"/><path d="M11 23L48 19L54 48Q47 58 27 56L12 50Z" fill="#9f7852"/><path d="M10 22L46 17L49 31L35 38L18 36Z" fill="#cfab77"/><path d="M29 29L36 30L36 39L29 39Z" fill="#f0d59a"/><path d="M47 10L55 4L61 13L54 21Z" fill="#7aa58a"/>',
    "power": '<path d="M10 45L15 52L40 26L34 20Z" fill="#a57748"/><path d="M25 17L40 7L53 13L57 24L46 34L32 32Z" fill="#a18a76"/><path d="M32 16L41 11L49 15M28 22L36 22" fill="none" stroke="#d7b99a"/>',
    "crit_chance": '<path d="M5 33Q18 17 32 16Q46 17 59 32Q46 47 32 49Q18 46 5 33Z" fill="#dfb46d"/><ellipse cx="32" cy="32" rx="9" ry="10" fill="#77543a"/><path d="M47 6L48 12L55 14L49 17L48 24L44 18L37 16L44 12Z" fill="#f2d398"/>',
    "crit_power": '<path d="M35 6L41 23L58 24L45 36L48 54L32 45L16 55L19 37L6 26L25 23Z" fill="#d58255"/><path d="M33 18L35 31L46 31L36 36L37 45L30 37L22 41L26 33L21 28L30 29Z" fill="#f3d48e"/>',
    "haste": '<path d="M12 42L34 20L30 15L54 9L50 33L44 29L23 52Z" fill="#cb974f"/><path d="M9 25L24 12M5 35L16 24M28 52L40 43" fill="none" stroke="#97613c"/>',
    "speed": '<path d="M41 5C29 7 21 18 19 29L10 38L16 49L29 54L49 47L47 38L34 35L36 23L46 16Z" fill="#b9956a"/><path d="M14 40L31 47L47 42M26 23L36 26M23 30L34 33" fill="none" stroke="#e6ca99"/><path d="M5 18L15 15M4 29L13 25" fill="none" stroke="#6b8c62"/>',
    "armor": '<path d="M10 14L31 7L55 15L51 42L31 57L13 43Z" fill="#8f9a81"/><path d="M18 20L32 15L45 20L42 38L31 47L20 38Z" fill="#d3bd99"/><path d="M31 17L31 45" fill="none" stroke="#716754"/>',
    "regen": '<path d="M33 56Q25 33 35 12" fill="none" stroke="#507653" stroke-width="5"/><path d="M33 29Q30 7 54 9Q53 28 33 29Z" fill="#93a675"/><path d="M28 39Q7 39 9 19Q29 19 28 39Z" fill="#70926a"/><path d="M34 27L47 15M27 36L15 25" fill="none" stroke="#d0c494"/>',
    "dodge": '<path d="M11 48Q19 27 40 13L33 8L58 8L54 32L46 25Q24 33 22 49Z" fill="#88aaa1"/><path d="M8 35L14 27M4 47L8 41M34 49L40 42" fill="none" stroke="#577c79"/>',
    "accuracy": '<path d="M5 31Q31 11 59 31Q31 52 5 31Z" fill="#86a4a0"/><circle cx="32" cy="31" r="10" fill="#edc28b"/><circle cx="32" cy="31" r="4" fill="#493a30"/><path d="M32 6V15M32 47V57M7 31H14M50 31H58" fill="none" stroke="#665e4a"/>',
    "area": '<ellipse cx="32" cy="39" rx="26" ry="15" fill="#dcc184"/><ellipse cx="32" cy="38" rx="15" ry="8" fill="none" stroke="#a86743"/><path d="M32 9L38 28L32 34L25 28Z" fill="#bd7651"/><path d="M11 10L15 18M52 9L48 18" fill="none" stroke="#a86743"/>',
    "pierce": '<path d="M17 46L49 15" fill="none" stroke="#9a7752" stroke-width="6"/><path d="M40 14L59 6L52 24Z" fill="#90b5a8"/><path d="M11 37L18 33L24 40L20 50L8 56Z" fill="#d6b987"/><path d="M35 28L37 40M29 24L20 23" fill="none" stroke="#788a7a"/>',
    "ricochet": '<path d="M8 41L24 19L41 37L55 13" fill="none" stroke="#659295" stroke-width="6"/><path d="M44 12L57 7L58 23Z" fill="#e7c78a"/><circle cx="24" cy="19" r="6" fill="#8caead"/><circle cx="41" cy="37" r="6" fill="#8caead"/>'
}
static var cache: Dictionary = {}

static func texture(key: String) -> Texture2D:
    if not cache.has(key):
        var image := Image.new()
        var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g stroke="#493326" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % DRAWINGS.get(key, DRAWINGS["heal"])
        if image.load_svg_from_string(svg, 2.0) != OK:
            return null
        cache[key] = ImageTexture.create_from_image(image)
    return cache[key]
