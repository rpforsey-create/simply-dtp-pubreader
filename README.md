# Simply DTP — Publisher reader

Builds the open-source **libmspub** Publisher reader (the one LibreOffice uses) as WebAssembly,
so Simply DTP can open Microsoft Publisher (.pub) files directly in the browser.

- GitHub builds it automatically whenever files change (see the **Actions** tab).
- The result (`pubreader.mjs` and `pubreader.wasm`) is attached to each successful run as **pubreader**.
- Those two files go into Simply DTP's `js/vendor/pubreader/` folder.

See `LICENCES.md` for the licences of everything included.
