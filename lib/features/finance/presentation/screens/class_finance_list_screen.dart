// DEPRECATED — Laporan per kelas landing screen.
//
// The intermediate "Laporan per kelas" screen (flat class list before
// drilling into a single class's matrix) was removed during the KU.5
// keuangan redesign. The same data is now reachable from the Tagihan
// tab's grouped Tingkat → Kelas rows, which already show the relevant
// status + outstanding info inline.
//
// This file is kept as an empty shim because the sandbox mount the
// agent runs in can refuse `unlink` syscalls — see CLAUDE.md ("File
// management inside a sandboxed session"). On a dev machine this file
// can be deleted outright.
library;
