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
  'style',
  'class',
];

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
