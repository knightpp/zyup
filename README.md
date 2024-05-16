# zyup - Zig Yarn UPgrade

## Why

I started learning Zig and wanted to code something in it. It was fun.

## What does it do

yarn by default won't touch `package.json` file when upgrading dependencies, it will only change
yarn.lock file. But `yarn upgrade dep-name@^` changes `package.json`. One downside, you cannot
upgrade all deps like that, so here helps zyup.

## How to use

```shell
$ zig build
$ ./zig-out/bin/zyup 'path to package.json'
```

## License

MIT
