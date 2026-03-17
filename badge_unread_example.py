"""Generate badge unread example images for tester reference"""
from PIL import Image, ImageDraw, ImageFont
import os

# Create images directory
output_dir = '/Users/macbook/development/projects/non-FCM/manajemennonfcm'

def draw_rounded_rect(draw, xy, radius, fill=None, outline=None, width=1):
    """Draw a rounded rectangle"""
    x1, y1, x2, y2 = xy
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)

def create_badge_example():
    """Create a visual example of badge unread indicators"""
    W, H = 800, 1100
    img = Image.new('RGB', (W, H), '#F8FAFC')
    draw = ImageDraw.Draw(img)

    # Try to use a good font
    try:
        font_title = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 24)
        font_header = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
        font_normal = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 14)
        font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 12)
        font_badge = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 11)
        font_badge_sm = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 9)
    except:
        font_title = ImageFont.load_default()
        font_header = font_title
        font_normal = font_title
        font_small = font_title
        font_badge = font_title
        font_badge_sm = font_title

    y = 20

    # ============ TITLE ============
    draw.text((W//2, y), "CONTOH BADGE UNREAD", fill='#1B4F72', font=font_title, anchor='mt')
    y += 35
    draw.text((W//2, y), "Referensi untuk Tester — Cara mengecek badge unread di aplikasi", fill='#5D6D7E', font=font_small, anchor='mt')
    y += 40

    # ============ SECTION 1: Menu Item Card ============
    draw.text((30, y), "1. BADGE PADA MENU ITEM (Dashboard)", fill='#1B4F72', font=font_header)
    y += 30

    # -- Card WITH badge --
    card_x, card_y = 40, y
    card_w, card_h = 340, 66
    # Card background
    draw_rounded_rect(draw, (card_x, card_y, card_x+card_w, card_y+card_h), 14, fill='#FFFFFF', outline='#E2E8F0', width=1)
    # Icon container
    icon_x, icon_y = card_x+12, card_y+11
    draw_rounded_rect(draw, (icon_x, icon_y, icon_x+44, icon_y+44), 12, fill='#EBF5FB', outline='#D6EAF8', width=1)
    draw.text((icon_x+22, icon_y+22), "📢", font=font_normal, anchor='mm')
    # Title
    draw.text((icon_x+56, card_y+26), "Pengumuman", fill='#1E293B', font=font_normal)
    # BADGE - Red pill
    badge_x = card_x + card_w - 70
    badge_y = card_y + 22
    draw_rounded_rect(draw, (badge_x, badge_y, badge_x+36, badge_y+22), 12, fill='#DC2626')
    draw.text((badge_x+18, badge_y+11), "3", fill='white', font=font_badge, anchor='mm')
    # Arrow
    draw.text((card_x+card_w-25, card_y+33), "›", fill='#94A3B8', font=font_header, anchor='mm')

    # Label arrow
    draw.line((card_x+card_w+10, badge_y+11, card_x+card_w+50, badge_y+11), fill='#DC2626', width=2)
    draw.text((card_x+card_w+55, badge_y+5), "Badge Unread", fill='#DC2626', font=font_small)
    draw.text((card_x+card_w+55, badge_y+19), "(ada 3 belum dibaca)", fill='#DC2626', font=font_small)

    y += 80

    # -- Card WITHOUT badge --
    card_y = y
    draw_rounded_rect(draw, (card_x, card_y, card_x+card_w, card_y+card_h), 14, fill='#FFFFFF', outline='#E2E8F0', width=1)
    icon_y = card_y+11
    draw_rounded_rect(draw, (icon_x, icon_y, icon_x+44, icon_y+44), 12, fill='#E8F8F5', outline='#D1FAE5', width=1)
    draw.text((icon_x+22, icon_y+22), "📋", font=font_normal, anchor='mm')
    draw.text((icon_x+56, card_y+26), "Aktivitas Kelas", fill='#1E293B', font=font_normal)
    draw.text((card_x+card_w-25, card_y+33), "›", fill='#94A3B8', font=font_header, anchor='mm')

    # Label
    draw.line((card_x+card_w+10, card_y+33, card_x+card_w+50, card_y+33), fill='#27AE60', width=2)
    draw.text((card_x+card_w+55, card_y+27), "Tidak ada badge", fill='#27AE60', font=font_small)
    draw.text((card_x+card_w+55, card_y+41), "(semua sudah dibaca ✓)", fill='#27AE60', font=font_small)

    y += 100

    # ============ SECTION 2: Quick Action Button ============
    draw.text((30, y), "2. BADGE PADA QUICK ACTION BUTTON", fill='#1B4F72', font=font_header)
    y += 35

    # Draw 4 quick action buttons side by side
    buttons = [
        ("Pengumuman", "📢", '#2E86C1', 5),
        ("Aktivitas", "📋", '#27AE60', 2),
        ("Nilai", "📊", '#E67E22', 0),
        ("Kehadiran", "📅", '#8E44AD', 0),
    ]

    btn_start_x = 50
    for i, (label, emoji, color, count) in enumerate(buttons):
        bx = btn_start_x + i * 90
        by = y
        # Button container
        draw_rounded_rect(draw, (bx, by, bx+65, by+54), 16, fill=color+'1A', outline='#E2E8F0', width=1)
        draw.text((bx+32, by+27), emoji, font=font_normal, anchor='mm')

        # Badge circle
        if count > 0:
            cx, cy = bx+58, by-2
            # White border circle
            draw.ellipse((cx-10, cy-10, cx+10, cy+10), fill='white')
            # Red circle
            draw.ellipse((cx-8, cy-8, cx+8, cy+8), fill='#DC2626')
            badge_text = str(count) if count <= 9 else '9+'
            draw.text((cx, cy), badge_text, fill='white', font=font_badge_sm, anchor='mm')

        # Label
        draw.text((bx+32, by+64), label, fill='#475569', font=font_small, anchor='mt')

    # Annotation arrows
    ann_y = y - 15
    draw.line((btn_start_x + 58, ann_y, btn_start_x + 58, ann_y - 20), fill='#DC2626', width=2)
    draw.line((btn_start_x + 58, ann_y - 20, btn_start_x + 200, ann_y - 20), fill='#DC2626', width=2)
    draw.text((btn_start_x + 205, ann_y - 26), "Lingkaran merah = ada unread", fill='#DC2626', font=font_small)

    draw.line((btn_start_x + 90 + 58, ann_y, btn_start_x + 90 + 58, ann_y - 35), fill='#DC2626', width=2)
    draw.line((btn_start_x + 90 + 58, ann_y - 35, btn_start_x + 360, ann_y - 35), fill='#DC2626', width=2)

    y += 110

    # ============ SECTION 3: Sebelum dan Sesudah dibaca ============
    draw.text((30, y), "3. SEBELUM vs SESUDAH DIBACA", fill='#1B4F72', font=font_header)
    y += 35

    # Before
    draw.text((80, y), "SEBELUM", fill='#DC2626', font=font_header)
    draw.text((80, y+22), "(belum buka halaman)", fill='#7F8C8D', font=font_small)
    y_before = y + 45

    # Before card
    draw_rounded_rect(draw, (50, y_before, 370, y_before+66), 14, fill='#FFFFFF', outline='#E2E8F0', width=1)
    draw_rounded_rect(draw, (62, y_before+11, 106, y_before+55), 12, fill='#FEF3C7', outline='#FDE68A', width=1)
    draw.text((84, y_before+33), "📊", font=font_normal, anchor='mm')
    draw.text((118, y_before+26), "Nilai", fill='#1E293B', font=font_normal)
    # Badge
    draw_rounded_rect(draw, (290, y_before+22, 340, y_before+44), 12, fill='#DC2626')
    draw.text((315, y_before+33), "12", fill='white', font=font_badge, anchor='mm')
    draw.text((355, y_before+33), "›", fill='#94A3B8', font=font_header, anchor='mm')

    y += 120

    # Arrow down
    draw.text((210, y), "⬇️  Buka halaman Nilai, scroll lihat data  ⬇️", fill='#5D6D7E', font=font_small, anchor='mt')
    y += 30

    # After
    draw.text((80, y), "SESUDAH", fill='#27AE60', font=font_header)
    draw.text((80, y+22), "(sudah buka & baca)", fill='#7F8C8D', font=font_small)
    y_after = y + 45

    # After card - no badge
    draw_rounded_rect(draw, (50, y_after, 370, y_after+66), 14, fill='#FFFFFF', outline='#E2E8F0', width=1)
    draw_rounded_rect(draw, (62, y_after+11, 106, y_after+55), 12, fill='#FEF3C7', outline='#FDE68A', width=1)
    draw.text((84, y_after+33), "📊", font=font_normal, anchor='mm')
    draw.text((118, y_after+26), "Nilai", fill='#1E293B', font=font_normal)
    # No badge! Just arrow
    draw.text((355, y_after+33), "›", fill='#94A3B8', font=font_header, anchor='mm')

    # Check mark
    draw.text((300, y_after+27), "✅ Badge hilang!", fill='#27AE60', font=font_small)

    y = y_after + 90

    # ============ SECTION 4: Cara Test ============
    draw.text((30, y), "4. LANGKAH TESTING BADGE UNREAD", fill='#1B4F72', font=font_header)
    y += 30

    steps = [
        ("① ", "Login → Buka Dashboard"),
        ("② ", "Perhatikan menu yang punya BADGE MERAH (angka)"),
        ("③ ", "Catat jumlah badge di setiap menu"),
        ("④", "Buka halaman tersebut (contoh: Pengumuman)"),
        ("⑤ ", "Scroll/baca semua konten di halaman"),
        ("⑥ ", "Kembali ke Dashboard"),
        ("⑦ ", "Verifikasi: Badge HARUS HILANG atau angka berkurang"),
        ("⑧ ", "Jika badge MASIH ADA setelah dibaca → LAPORKAN BUG!"),
    ]

    for step_num, step_text in steps:
        # Step background
        color_bg = '#FEE2E2' if '⑧' in step_num else '#F0F9FF'
        color_text = '#DC2626' if '⑧' in step_num else '#1E293B'
        draw_rounded_rect(draw, (50, y, 750, y+30), 8, fill=color_bg)
        draw.text((60, y+7), f"{step_num}", fill=color_text, font=font_normal)
        draw.text((95, y+8), step_text, fill=color_text, font=font_normal)
        y += 36

    y += 15

    # ============ SECTION 5: Menu yang punya badge ============
    draw.text((30, y), "5. DAFTAR MENU YANG PUNYA BADGE", fill='#1B4F72', font=font_header)
    y += 30

    menus_guru = [
        ("Guru:", "#27AE60", ["Pengumuman", "Aktivitas Kelas", "RPP", "Materi"]),
    ]
    menus_wali = [
        ("Wali:", "#8E44AD", ["Pengumuman", "Aktivitas Kelas", "Nilai", "Kehadiran", "Billing"]),
    ]

    for role, color, items in menus_guru + menus_wali:
        draw_rounded_rect(draw, (50, y, 750, y+32), 8, fill=color+'15')
        draw.text((60, y+8), role, fill=color, font=font_normal)
        items_text = "  |  ".join(items)
        draw.text((120, y+8), items_text, fill='#1E293B', font=font_normal)
        y += 40

    # Save
    output_path = os.path.join(output_dir, 'contoh_badge_unread.png')
    img.save(output_path, 'PNG', quality=95)
    print(f"Image saved: {output_path}")
    return output_path

if __name__ == '__main__':
    create_badge_example()
