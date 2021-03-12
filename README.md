# tele-tabby.nvim

Add a tab list to Telescope with information about each tab's working directory.

## Requires

`telescope` to both be installed.


## Exports

`teletabby.list`
- `require('telescope').extensions.tele_tabby.list()`
- similar to `live_grep`, but more async-ish

## Configuration

```lua
require('telescope').setup {
    extensions = {
        tele_tabby = {
            use_highlighter = true,
        }
    }
}
```

## TODO

Add more configuration options
- how to choose project root
- use colors
- shorten paths
