# yubisaki

App that triggers app-specific keyboard shortcuts from macOS trackpad gestures.

## Requirements

- macOS 15+
- Sandbox disabled (needed for Input Monitoring)

## Development

```bash
swift build   # build
swift run     # run
swift test    # test
```

## Building the app (personal use only, not distributed)

```bash
scripts/build-app.sh          # uses the version in Packaging/VERSION
scripts/build-app.sh 0.2.0    # or override it
```

Produces `dist/Yubisaki.app` — drag into `/Applications`.

It's ad-hoc signed, so Gatekeeper may warn on first launch (right-click → Open, or
`xattr -cr dist/Yubisaki.app`). Ad-hoc signatures change on every rebuild, so
Accessibility/Input Monitoring permissions need re-granting each time.

## License

[MIT](LICENSE)
