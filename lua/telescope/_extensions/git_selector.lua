local git_selector = require('git_selector')

return require('telescope').register_extension {
    setup = function(ext_config, _)
        git_selector.setup(ext_config)
    end,
    -- Telescope commands
    exports = {
        git_selector = git_selector.files,  -- Default action
        files = git_selector.files,
        grep = git_selector.grep,
        live_grep = git_selector.live_grep,
    }
}
