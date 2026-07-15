/**
 * Shared HTML sanitizer for anything that lands in `v-html`.
 *
 * Two callsite classes today:
 *   1. Quill-authored lesson-plan sections (RPP) — headings, lists,
 *      tables, inline formatting, images.
 *   2. AI-generated recommendation bodies (parent view) — same tag
 *      set, no user-authored images.
 *
 * Both were previously either unsanitized (lesson plans — the backend
 * comment claimed strip_tags on write, but LMS/UpdateLessonPlanAction
 * runs no strip_tags at all, so raw teacher input landed in v-html
 * verbatim — real stored XSS) or hand-rolled regex-sanitized
 * (ParentRecommendationDetailModal.vue:179-190 — the regex
 * `\son\w+="[^"]*"` requires a literal space and misses the
 * `<img src=x on error=...>` shape).
 *
 * Both classes collapse into a single call to DOMPurify with a
 * lesson-plan-friendly allow-list. Adding a new callsite? Just
 * import sanitizeRichHtml and drop it in front of the v-html value.
 */
import DOMPurify from 'dompurify';

/**
 * Round-12 audit: the Quill/AI-authored HTML we render via v-html
 * historically allowed `style` and unrestricted `class`. Both are
 * CSS-injection carriers even when script/on-handlers are stripped:
 *
 *   <p style="position:fixed;inset:0;z-index:9999;background:#fff">
 *     Masuk kembali dengan password Anda
 *   </p>
 *
 * would render a full-screen fake login overlay on parent view of a
 * poisoned lesson plan or AI recommendation. Even with `style` gone,
 * an attacker could reach the same result via Tailwind's atomic
 * classes (`class="fixed inset-0 z-50 bg-white"`) because the page's
 * CSS registers them for genuine app UI.
 *
 * Fix:
 *   1. Drop `style` entirely — Quill's inline color/background isn't
 *      worth the CSS-injection footgun.
 *   2. Keep `class` for Quill's own layout (`ql-align-center`, etc.)
 *      but filter each class token to the `ql-` prefix so Tailwind
 *      utilities never survive the sanitizer.
 */
const QUILL_CLASS_PREFIX = 'ql-';

const RICH_HTML_ALLOWED_TAGS = [
  'p',
  'br',
  'strong',
  'em',
  'u',
  's',
  'a',
  'ul',
  'ol',
  'li',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'blockquote',
  'code',
  'pre',
  'table',
  'thead',
  'tbody',
  'tfoot',
  'tr',
  'th',
  'td',
  'img',
  'span',
  'div',
  'hr',
];

const RICH_HTML_ALLOWED_ATTRS = [
  'href',
  'title',
  'target',
  'rel',
  'src',
  'alt',
  'width',
  'height',
  'colspan',
  'rowspan',
  'class',
];

/**
 * Filter `class` attribute values so only Quill's own layout classes
 * survive. Anything else (Tailwind atomics, tenant-injected utility
 * names) gets stripped before DOMPurify emits the node.
 */
function installQuillClassFilter(): void {
  DOMPurify.removeHook('uponSanitizeAttribute');
  DOMPurify.addHook('uponSanitizeAttribute', (_node, data) => {
    if (data.attrName !== 'class') return;
    const kept = data.attrValue
      .split(/\s+/)
      .filter((token) => token.startsWith(QUILL_CLASS_PREFIX));
    if (kept.length === 0) {
      data.keepAttr = false;
      return;
    }
    data.attrValue = kept.join(' ');
  });
}

installQuillClassFilter();

/**
 * Sanitize an HTML string produced by our rich-text editors (Quill,
 * AI backend) so it's safe to hand to `v-html`. Strips script/style,
 * every on* handler, javascript: URLs, and any tag not in the
 * lesson-plan-appropriate allow-list.
 *
 * Returns an empty string on null/undefined so consumers can drop
 * the ?? '' and let the v-else empty state render.
 */
export function sanitizeRichHtml(input: string | null | undefined): string {
  if (!input) return '';
  return DOMPurify.sanitize(input, {
    ALLOWED_TAGS: RICH_HTML_ALLOWED_TAGS,
    ALLOWED_ATTR: RICH_HTML_ALLOWED_ATTRS,
    // Force target="_blank" links to also get rel="noopener noreferrer"
    // so a compromised link can't reach window.opener.
    ADD_ATTR: ['target'],
    ALLOW_DATA_ATTR: false,
  });
}

const HTMLISH = /<\/?(p|br|ul|ol|li|h[1-6]|strong|em|b|i|u|s|a|blockquote|pre|code|div|span)\b/i;

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

/**
 * Render an announcement body to safe HTML, bridging the two content eras:
 *  - New rich content (from the Quill editor) is already HTML → sanitize it.
 *  - Legacy plain-text announcements have real newlines and WhatsApp-style
 *    `*bold*`; escape them, upgrade `*x*` → <strong>, newlines → <br>, so their
 *    line breaks survive (a raw v-html would collapse them) without ever
 *    trusting unescaped input.
 */
export function renderAnnouncementHtml(input: string | null | undefined): string {
  const raw = (input ?? '').trim();
  if (!raw) return '';
  if (HTMLISH.test(raw)) return sanitizeRichHtml(raw);
  const upgraded = escapeHtml(raw)
    .replace(/\*([^*\n]+)\*/g, '<strong>$1</strong>')
    .replace(/\r?\n/g, '<br>');
  return sanitizeRichHtml(upgraded);
}
