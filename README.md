# telescope-git-selector.nvim

*Telescope Git Selector* is a [Telescope](https://github.com/nvim-telescope/telescope.nvim)
extension that searches for Git worktrees and opens files in the selected worktree.

When a repository is selected its files are searched using the builtin
`Telescope git_files` command.

The [telescope-git-grep.nvim](https://gitlab.com/davvid/telescope-git-grep.nvim)
extension can be used as well to search within files in selected worktrees.

## Installation

The following tools are optional and recommended in order to improve the
the user experience when using `git_selector`:

* [fdfind](https://github.com/sharkdp/fd) is used to find worktrees on Windows.
`find` is used on non-Windows platforms (Linux, macOS, BSD, ...).

The `grep` and `live_grep` commands require
[telescope-git-grep.nvim](https://gitlab.com/davvid/telescope-git-grep.nvim).

You can install this plugin using your favorite vim package manager, eg.
[vim-plug](https://github.com/junegunn/vim-plug),
[lazy](https://github.com/folke/lazy.nvim).

**lazy**:
```lua
{
    "https://gitlab.com/davvid/telescope-git-selector.nvim"
    dependencies = { "https://gitlab.com/davvid/telescope-git-grep.nvim" }
}
```

**vim-plug**
```VimL
Plug 'https://gitlab.com/davvid/telescope-git-grep.nvim'
Plug 'https://gitlab.com/davvid/telescope-git-selector.nvim'
```


## Usage

Activate the custom Telescope commands and `git_selector` extension by adding

```lua
require('telescope').load_extension('git_selector')
```

somewhere after your `require('telescope').setup()` call.
This is typically all you need to configure the plugin.

The following `Telescope` extension commands are provided:

```VimL
:Telescope git_selector
:Telescope git_selector files
:Telescope git_selector grep
:Telescope git_selector live_grep

" Specify the location to search.
:Telescope git_selector search=~/src
```

These commands can also be used from your `init.lua`.

For example, to bind `files` to `<leader>sf`, `grep` to `<leader>sg` and
`live_grep` to `<leader>sG` use:

```lua
-- Search for the files within the selected Git worktree.
vim.keymap.set({'n', 'v'}, '<leader>sg', function()
    require('git_selector').files()
end)

-- Search for the current word and fuzzy-search over the result using git_grep.grep().
vim.keymap.set({'n', 'v'}, '<leader>sg', function()
    require('git_selector').grep()
end)

-- Interactively search for a pattern using git_grep.live_grep().
vim.keymap.set('n', '<leader>sG', function()
    require('git_selector').live_grep()
end)
```


## Configuration

You can configure `git_selector` using either Telescope **or** a direct `setup()` call.

If using telescope, it is recommend that you set `dynamic_preview_title = true`
so that the preview window title is updated alongside the current selection.

```lua
-- Telescope
require('telescope').setup({
    -- Telescope core configuration
    defaults = {
        dynamic_preview_title = true,  -- Enable dynamic preview titles
    },
    extensions = {
        -- Git Selector configuration
        git_selector = {
            depth = 2,          -- Set to -1 to search without limit.
            follow = true,      -- Set to false to disable following symlinks.
            search = {          -- Set to a list or string to specify the locations to search.
                '~'             -- Defaults to searching $HOME.
            },
            options = {         -- Default options passed to inner commands.
                files = {},     -- Defaults for telescope.builtin.git_files().
                grep = {},      -- Defaults for git_grep.grep().
                live_grep = {}, -- Defaults for git_grep.live_grep().
            }
        }
    }
})
-- Direct configuration
require('git_selector').setup({
    depth = 2,          -- Set to -1 to search without limit.
    follow = true,      -- Set to false to disable following symlinks.
    search = {          -- Set to a list or string to specify the locations to search.
        '~'             -- Defaults to searching $HOME.
    },
    options = {         -- Default options passed to inner commands.
        files = {},     -- Defaults for telescope.builtin.git_files().
        grep = {},      -- Defaults for git_grep.grep().
        live_grep = {}, -- Defaults for git_grep.live_grep().
    }
})
```

The values shown above are the default values. You do not need to specify the
`git_selector = {...}` Telescope extensions configuration or call
`git_selector.setup()` if the defaults work fine for you as-is.

You can also pass a `{ depth = ..., search = ... }` table as the first argument
directly to `git_selector` functions to set these values at specific call sites.

As demonstrated in the `:Telescope git_selector` examples above, the `search`
and `depth` fields can be passed to the
`:Telescope git_selector {files,grep,live_grep}` commands.

### Options

The following fields are optional and can specified to override their
default values.

* `depth` - Limits the traversal depth when walking the file system tree
searching for worktrees. Specify `-1` to make the depth unlimited.
Defaults to `2`.

* `search` - Specify the directories to search for Git worktrees.
This field accepts a list of paths that are expanded using `vim.fn.expand(path)`.
Defaults to `search = { '~' }` (i.e. `$HOME`).

* `follow` - Symlinks are followed by default. Set `follow` to `false` to disable
following symlinks.

* `options` - Specify the default values that are used when calling the inner commands
used by this plugin. The key name corresponds to the name of the command.


## Development

The [Garden file](garden.yaml) can be used to run lint checks using
[Garden](https://gitlab.com/garden-rs/garden).

```sh
# Run lint checks using "luacheck"
garden check
```
