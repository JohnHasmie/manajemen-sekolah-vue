<!--
  AppRichTextEditor.vue — Quill-based rich text editor (Vue 3 wrapper).

  Why Quill: matches the Flutter app's `flutter_quill` setup, so the
  HTML stored in `lesson_plans.format_data` round-trips cleanly
  between mobile + web. Snow theme gives the canonical toolbar
  (bold / italic / lists / headers / link) without writing custom UI.

  Usage:
    <AppRichTextEditor v-model:html="myHtml" placeholder="Tulis…" />

  Two-way binding via `html` so the parent owns the raw HTML string
  (what the backend stores). The component shadows it as the editor's
  Delta internally — emits on `text-change` so v-model stays live.

  Notes:
    - Toolbar is locked to a teacher-friendly subset; remove
      attributes from TOOLBAR to trim further.
    - The component imports the snow theme CSS itself so consumers
      don't have to remember it.
    - Sets `min-h-[240px]` by default — pass `:min-height` to override.
-->
<script setup lang="ts">
import {
  nextTick,
  onBeforeUnmount,
  onMounted,
  ref,
  watch,
} from 'vue';
import Quill from 'quill';
import 'quill/dist/quill.snow.css';

const props = withDefaults(
  defineProps<{
    /** Current HTML content (two-way: `v-model:html`). */
    html: string;
    placeholder?: string;
    /** Disable editing. */
    readonly?: boolean;
    /** Editor min-height in pixels. */
    minHeight?: number;
  }>(),
  {
    placeholder: 'Tulis di sini…',
    readonly: false,
    minHeight: 240,
  },
);

const emit = defineEmits<{
  'update:html': [value: string];
  /** Fired after each user edit, useful for "auto-save" hooks. */
  change: [];
}>();

const rootEl = ref<HTMLDivElement | null>(null);
let quill: Quill | null = null;

// Toolbar — purposefully focused on RPP editing needs.
// Add 'image' / 'video' later if uploads land.
const TOOLBAR = [
  [{ header: [1, 2, 3, false] }],
  ['bold', 'italic', 'underline', 'strike'],
  [{ list: 'ordered' }, { list: 'bullet' }],
  [{ indent: '-1' }, { indent: '+1' }],
  [{ align: [] }],
  ['blockquote', 'code-block'],
  ['link'],
  ['clean'],
];

// Internal echo flag — when we set HTML programmatically (parent
// hydrated initial value, or v-model upstream change), Quill fires
// text-change → we'd push the same value back up → infinite loop.
let suppressNextEmit = false;

function setHtml(next: string) {
  if (!quill) return;
  // Defensive empty-check — Quill represents "no content" as
  // `<p><br></p>` so an empty string causes a flicker.
  const cleaned = (next ?? '').trim();
  // Compare against current root HTML to avoid resetting the cursor
  // on every keystroke.
  const current = quill.root.innerHTML;
  if (cleaned === current) return;
  if (cleaned === '' && (current === '<p><br></p>' || current === '')) return;
  suppressNextEmit = true;
  // Quill's clipboard.dangerouslyPasteHTML preserves the editor's
  // formats whitelist; raw assignment to .innerHTML loses block-level
  // attributes Quill needs to round-trip.
  quill.clipboard.dangerouslyPasteHTML(cleaned, 'silent');
}

onMounted(async () => {
  if (!rootEl.value) return;
  quill = new Quill(rootEl.value, {
    theme: 'snow',
    placeholder: props.placeholder,
    readOnly: props.readonly,
    modules: { toolbar: TOOLBAR },
  });
  // Seed initial content. nextTick because Quill mounts its toolbar
  // synchronously and we don't want our HTML push fighting that.
  await nextTick();
  if (props.html) setHtml(props.html);

  quill.on('text-change', () => {
    if (suppressNextEmit) {
      suppressNextEmit = false;
      return;
    }
    const next = quill!.root.innerHTML;
    // Treat the "empty document" representation as empty string so the
    // parent's required-field validation works as expected.
    emit('update:html', next === '<p><br></p>' ? '' : next);
    emit('change');
  });
});

onBeforeUnmount(() => {
  // Quill 2 doesn't expose .destroy() — clean up listeners manually.
  if (quill) {
    quill.off('text-change');
    quill = null;
  }
});

// React to parent-side HTML changes (e.g. parent loaded a fresh
// section via "regenerate"). Only push when meaningfully different.
watch(
  () => props.html,
  (next) => {
    if (!quill) return;
    setHtml(next ?? '');
  },
);

watch(
  () => props.readonly,
  (next) => {
    quill?.enable(!next);
  },
);
</script>

<template>
  <div
    class="rich-editor-wrapper bg-white rounded-xl border border-slate-200 overflow-hidden focus-within:border-brand-cobalt focus-within:ring-2 focus-within:ring-brand-cobalt/15 transition"
  >
    <div
      ref="rootEl"
      class="prose-editor"
      :style="{ minHeight: `${minHeight}px` }"
    />
  </div>
</template>

<style>
/* Tighten Quill's snow theme so it matches the rest of the app
   (rounded card, slate borders, brand cobalt accents). Scoped to
   this wrapper class so other Quill instances aren't affected. */
.rich-editor-wrapper .ql-toolbar.ql-snow {
  border: 0;
  border-bottom: 1px solid rgb(226 232 240); /* slate-200 */
  background: rgb(248 250 252); /* slate-50 */
  padding: 6px 8px;
}
.rich-editor-wrapper .ql-container.ql-snow {
  border: 0;
  font-family: inherit;
  font-size: 13px;
}
.rich-editor-wrapper .ql-editor {
  min-height: inherit;
  padding: 14px 16px;
  line-height: 1.65;
  color: rgb(15 23 42); /* slate-900 */
}
.rich-editor-wrapper .ql-editor.ql-blank::before {
  color: rgb(148 163 184); /* slate-400 */
  font-style: normal;
  left: 16px;
  right: 16px;
}
.rich-editor-wrapper .ql-snow .ql-stroke {
  stroke: rgb(71 85 105); /* slate-600 */
}
.rich-editor-wrapper .ql-snow .ql-fill {
  fill: rgb(71 85 105);
}
.rich-editor-wrapper .ql-snow .ql-picker {
  color: rgb(71 85 105);
}
.rich-editor-wrapper .ql-snow .ql-active .ql-stroke,
.rich-editor-wrapper .ql-snow button:hover .ql-stroke {
  stroke: rgb(27 111 184); /* brand-cobalt */
}
.rich-editor-wrapper .ql-snow .ql-active .ql-fill,
.rich-editor-wrapper .ql-snow button:hover .ql-fill {
  fill: rgb(27 111 184);
}
.rich-editor-wrapper .ql-snow .ql-active,
.rich-editor-wrapper .ql-snow button:hover {
  color: rgb(27 111 184);
}
</style>
