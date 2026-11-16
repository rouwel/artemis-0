# Browser edition / Vercel

The `web/vercel` branch is a browser-specific port of Artemis-0. The tagged
Linux release on `main` remains unchanged.

**Play online:** https://artemis-0.vercel.app

## Build locally

Install the Godot **4.7.2 stable standard** editor (`mise install`) and the
matching **Web** export templates through Godot's export template manager.
Then run:

```sh
python3 tools/package_web.py
```

This runs all three regression suites, exports `build/web/index.html` plus
the matching JS, WASM and PCK, and copies Vercel's static headers. To preview:

```sh
python3 -m http.server 8000 --directory build/web
```

Open `http://localhost:8000` in a WebGL 2-capable desktop browser. Browsers
must load this from a local server or HTTPS, not a `file://` URL. Click the
canvas to capture the pointer; **Esc** releases it.

## Deploy to Vercel

This branch's output is **prebuilt static content**. Vercel's build image does
not include the matching Godot engine/templates; do not import the source
branch as an unconfigured Vercel build. The export is ignored by Git. The
browser textures are capped at 1024 px so the complete export stays below
Vercel Hobby's 100 MB CLI upload limit.

From a machine with Vercel access, after building:

```sh
npx vercel@latest login
npx vercel@latest deploy build/web --prod
```

Choose a new static project named `artemis-0`, **without connecting a Git
repository** (the source branch cannot be built by Vercel itself). The
`vercel.json` copied into the export supplies WASM/PCK MIME types and safe
cache headers. No NASA key is needed or included. Link the project on
subsequent deploys or use `--project artemis-0`.

For automatic production updates, add the repository's GitHub Actions secrets
`VERCEL_TOKEN`, `VERCEL_ORG_ID`, and `VERCEL_PROJECT_ID`. The last two IDs are
in `build/web/.vercel/project.json` after the first CLI deployment, if you
link the folder; the token is created in your Vercel account settings. Linking
may also create `build/web/.env.local`; remove that local credential before
serving or packaging the export.
The workflow on `web/vercel` builds and checks the export on every push, and
deploys it when all three secrets are present. It caches the official Godot
Web template between builds; the first run downloads the full Godot template
archive. Vercel project Git integration should remain disconnected to avoid
an unconfigured second build. The deployed URL is shown in the action logs.

## Differences from Linux

- Godot Web uses the **Compatibility** renderer (WebGL 2), not Forward+.
- The export is single-threaded to avoid cross-origin isolation requirements.
- The historical NASA catalogue is bundled and browsable offline; optional
  live refresh is disabled in browsers. Linux remains the full-featured
  release with locally configured NASA credentials.
- Browser audio and full-screen/mouse capture may require a user gesture.
  The desktop browser build is the supported web target; mobile performance
  and Safari WebGL behavior are not guaranteed.
