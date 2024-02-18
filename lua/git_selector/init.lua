--- "git_selector" is the exported module.
local git_selector = {}
git_selector.config = {}

local actions = require('telescope.actions')
local actions_state = require('telescope.actions.state')
local conf = require('telescope.config').values
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local utils = require('telescope.utils')

--- Initialize global options.
git_selector.setup = function(opts)
    if opts ~= nil then
        for k, v in pairs(opts) do
            git_selector.config[k] = v
        end
    end
end

--- Initialize options
local get_git_selector_opts = function(opts, prompt_title)
    -- Operate on a copy of git_grep.config
    opts = vim.F.if_nil(opts, {})
    for k, v in pairs(git_selector.config) do
        if opts[k] == nil then
            opts[k] = v
        end
    end

    if opts.depth == nil then
        opts.depth = 2
    end
    if opts.follow == nil then
        opts.follow = true
    end
    if opts.options == nil then
        opts.options = {}
    end
    if opts.search == nil then
        opts.search = { '~' }
    elseif type(opts.search) == 'string' then
        opts.search = { opts.search }
    end
    if opts.prompt_title == nil then
        opts.prompt_title = prompt_title or 'Git Selector'
    end
    if opts.show_preview == nil then
        opts.show_preview = true
    end
    if opts.cwd == nil then
        opts.cwd = vim.loop.cwd()
    else
        opts.cwd = vim.fn.expand(opts.cwd)
    end
    opts.entry_maker = vim.F.if_nil(opts.entry_maker, git_selector.gen_from_git(opts))

    return opts
end

--- Build an "fd/fdfind" command for finding Git worktrees.
local get_fdfind_command = function(fdfind, opts)
    local fdfind_cmd =  fdfind
    if opts.depth > 0 then
        fdfind_cmd = fdfind_cmd .. ' --max-depth=' .. (opts.depth + 1)
    end
    fdfind_cmd = (
        fdfind_cmd
        .. ' --color=never'
        .. ' --case-sensitive'
        .. ' --hidden'
        .. ' --no-ignore'
    )
    --  Append opts.args to fdfind_args
    for _, path in ipairs(opts.search) do
        fdfind_cmd = fdfind_cmd
            .. (' --search-path %q'):format(vim.fn.expand(path))
    end
    fdfind_cmd = fdfind_cmd .. ' "^\\.git$" | xargs -P 4 -n 1 dirname 2>/dev/null'
    return { 'sh', '-c', fdfind_cmd }
end

--- Build a "find" command for finding Git worktrees.
local get_find_command = function(opts)
    local find_cmd = 'find'
    if opts.follow then
        find_cmd = find_cmd .. ' -L'
    end
    for _, path in ipairs(opts.search) do
        find_cmd = find_cmd .. (' %q'):format(vim.fn.expand(path))
    end
    if opts.depth > 0 then
        find_cmd = find_cmd .. ' -maxdepth ' .. (opts.depth + 1)
    end
    find_cmd = find_cmd .. ' -name .git -printf "%h\\n" 2>/dev/null'
    return { 'sh', '-c', find_cmd }
end

--- Build the find command.
local get_finder_command = function(opts)
    if opts.find_command then
        if type(opts.find_command) == 'function' then
            return opts.find_command(opts)
        end
        return opts.find_command
    end
    if vim.fn.executable('fdfind') == 1 then
        return get_fdfind_command('fdfind', opts)
    elseif vim.fn.executable('fd') == 1 then
        return get_fdfind_command('fd', opts)
    elseif vim.fn.executable('find') == 1 and vim.fn.has('win32') == 0 then
        return get_find_command(opts)
    else
        vim.notify(
            'git-selector: "find", "fdfind" and "fd"  could not be found. '
            ..  'Install  fd / fdfind. (sudo apt install fd-find)',
            vim.log.levels.ERROR
        )
        return nil
    end
end

--  Return the previewer to use
local get_previewer = function(opts)
    if opts.show_preview then
        return previewers.new_buffer_previewer({
            title = 'Preview',
            dyn_title = function(_, entry)
                return entry.value
            end,
            define_preview = function(self, entry)
                conf.buffer_previewer_maker(entry.value, self.state.bufnr, {
                    bufname = self.state.bufname,
                    winid = self.state.winid,
                    preview = opts.preview,
                    file_encoding = opts.file_encoding,
                })
            end
        })
    else
        return nil
    end
end

-- Return a file icon for the entry
git_selector.gen_from_git = function(opts)
    opts = opts or {}
    local disable_devicons = opts.disable_devicons
    local entry_maker = {
        cwd = opts.cwd,  -- Paths are displayed relative to opts.cwd.
        display = function(entry)  -- Transform the entry into a displayable value.
            local icon = '📁'
            local hl_group = 'DevIconFileFolder'
            local display = utils.transform_path(opts, entry.value)
            if disable_devicons then
                return display
            else
                return icon .. ' ' .. display, { { { 0, #icon }, hl_group } }
            end
        end
    }
    -- Handle lookups so that "entry.path" calculates a path.
    local lookup_keys = {
        display = 1,
        ordinal = 1,
        value = 1,
    }
    entry_maker.__index = function(t, k)
        local raw = rawget(entry_maker, k)
        if raw then
            return raw
        end
        return rawget(t, rawget(lookup_keys, k))
    end

    return function(line)
        return setmetatable({ line }, entry_maker)
    end
end

-- Select a Git worktree and run a function on the selected path.
git_selector.selector = function(fn, opts, extra_opts)
    local cmd = get_finder_command(opts)
    if cmd == nil then
        return
    end
    pickers.new(
        opts, {
            finder = finders.new_oneshot_job(cmd, opts),
            sorter = conf.file_sorter(opts),
            previewer = get_previewer(opts),
            prompt_title = opts.prompt_title,
            results_title = 'Worktrees',
            entry_maker = opts.entry_maker,
            attach_mappings = function(_, map)
                map('i', '<c-space>', actions.to_fuzzy_refine)
                actions.select_default:replace(function(prompt_bufnr)
                    local selection = actions_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if selection == nil then
                        return
                    end

                    local inner_opts = { cwd = selection.value }
                    if extra_opts ~= nil then
                        for k, v in pairs(extra_opts) do
                            if inner_opts[k] == nil then
                                inner_opts[k] = v
                            end
                        end
                    end

                    fn(inner_opts)
                end)
                return true
            end
        }
    ):find()
end

--- Find worktrees and search for files in the selected worktree.
git_selector.files = function(opts)
    local fn = require('telescope.builtin').git_files
    opts = get_git_selector_opts(opts, 'Git Selector (Files)')
    git_selector.selector(fn, opts, opts.options.files)
end

--- Find worktrees and grep files in the selected worktreee.
git_selector.grep = function(opts)
    local fn = require('git_grep').grep
    opts = get_git_selector_opts(opts, 'Git Selector (Grep)')
    git_selector.selector(fn, opts, opts.options.grep)
end

--- Find worktrees and live grep files in the selected worktree.
git_selector.live_grep = function(opts)
    local fn = require('git_grep').live_grep
    opts = get_git_selector_opts(opts, 'Git Selector (Live Grep)')
    git_selector.selector(fn, opts, opts.options.live_grep)
end

return git_selector
