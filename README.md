<img src="assets/icon.svg" width="64" height="64" alt="">

# lookup

Created in [T3 Code](https://t3.codes).

## Development

Requires `lua-language-server` (`pacman -S lua-language-server`) and `lua5.1`.

```sh
make setup   # fetch WoW API annotations and Blizzard's Forever UI source into .tools/
make update  # refresh both after a game patch
make link    # symlink Lookup/ into WoW Forever's AddOns folder
make check   # type-check against the WoW API
make test    # run tests/*_test.lua in plain Lua
make log     # print the session log saved on the last /reload
```

Edit a file, run `make check`, then `/reload` in game. Restart the client after you change `Lookup.toc`.
Set `WOW=...` if your `_forever_` folder is in a different place.

