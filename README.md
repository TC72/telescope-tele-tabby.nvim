# tele-tabby.nvim

A tab switcher extension for Telescope with information about each tab's working directory.

![Tab Preview](https://www.digitalbakery.net/images/tele-tabby-preview.gif)

Each Tab is shown with the path to the current buffer split into two parts.

![Tab Description](https://cln.sh/NlEExs+)

The project root is found by searching for a .git file. The file is shown with devicon colors which can be disabled.
If the buffer is not in the tab's cwd the full path is shown, this makes it easy to see a buffer which may have been opened in the wrong tab.

The extension is useful for a worklow where each tab is given its own working directory with tcd.
This allows you to use separate tabs to limit the results to the working directory when using telescope tools like find_files.

## Requires

`telescope` to be installed.


## Exports

`teletabby.list`
- `require('telescope').extensions.tele_tabby.list()`

Can be called with `:Telescope tele_tabby list`

## Recomended Setup

If you are using gruvbox color scheme the inverted highlighting can be turned off
```
let g:gruvbox_invert_selection=0
```

I prefer to use telescope's builtin dropdown theme
```
  local opts = themes.get_dropdown {
    winblend = 10,
    border = true,
    previewer = false,
    shorten_path = false,
    heigth=20,
    width= 120
  }
  require'telescope'.extensions.tele_tabby.list(opts)
```

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


### Options
| Keys            | Description                                | Options    |
| --------------- | ------------------------------------------ | ---------- |
| use_highlighter | Use devicon colors for the end of the path | true/false |


## TODO

Add more configuration options
- how to choose project root
- shorten paths
