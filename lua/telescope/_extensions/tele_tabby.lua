local has_telescope, telescope = pcall(require, 'telescope')
if not has_telescope then
  error('This plugins requires nvim-telescope/telescope.nvim')
end

local actions      = require'telescope.actions'
local state      = require'telescope.state'
local action_state = require'telescope.actions.state'
local builtin      = require'telescope.builtin'
local finders      = require'telescope.finders'
local pickers      = require'telescope.pickers'
local previewers   = require'telescope.previewers'
local conf         = require('telescope.config').values
local entry_display = require('telescope.pickers.entry_display')
local path = require('telescope.path')
local utils = require('telescope.utils')
local log = require('telescope.log')
local sorters = require('telescope.sorters')
local themes = require('telescope.themes')
local scan = require'plenary.scandir'


--[[
--  Most of the code is taken from the builtin buffers picker
--  internal.buffers
--  make_entry.gen_from_buffer
--]]


-- This is our action when a window is chosen
function goto_window(prompt_bufnr)
    actions.close(prompt_bufnr)
    local entry = action_state.get_selected_entry()
    -- entry.value gives us a window id
    -- this call switches to the tab containinfg the window
    vim.api.nvim_set_current_win( entry.value )
end


--[[
-- thanks to conni for the fucntion
-- use this instead of relying on lsp utils, we will always have plenary
-- recursively search through directories for the pattern
-- at each call add '/../' to move up the hierarchy
-- stops when we get a match or we hit / root directory
--]]

local root_pattern
root_pattern = function(start, pattern)
  if start == '/' then return nil end
  local res = scan.scan_dir(start, { search_pattern = pattern, hidden = true, add_dirs = true, depth = 1 })
  if table.getn(res) == 0 then
    local new = start .. '/../'
    return root_pattern(vim.loop.fs_realpath(new), pattern)
  else
    return start
  end
end


--[[
-- this is based on internal.buffers
-- ]]

local list = function(opts)
    opts = opts or {}

    -- use this code to remove windows which can't be focussed
    -- local win_conf = vim.api.nvim_win_get_config(winnr)
    --  local is_focusable = win_conf.relative == '' or win_conf.focusable

    -- Get a list of tabs and then find all the windows in each tab
    local tabnrs = vim.api.nvim_list_tabpages()
    local current_win = vim.api.nvim_get_current_win()
    local windows = {}

    -- set the selection to the default 1 but we'll try to set it to the current tab
    -- use idx to count up through the windows we find and use it to set selection_idx
    local selection_idx = 1
    local idx = 0

    -- get both tabidx and tabnr, a tab always keeps its tabnr
    -- but it can be moved to a different tabidx with tabmove
    -- or when another tab gets deleted
    for tabidx, tabnr in ipairs(tabnrs) do
        -- Get the windows of this tab
        local windownrs = vim.api.nvim_tabpage_list_wins(tabnr)
        for windownr, windowid in ipairs(windownrs) do
            idx = idx+1
            if windowid == current_win then
                -- found the current window
                selection_idx = idx
            end

            -- the bufnr 
            local bufnr = vim.api.nvim_win_get_buf(windowid)

            -- find the cwd of this window, check in order of priority, lcd, tcd, cwd
            local cwd = vim.fn.expand( vim.fn.haslocaldir( windownr, tabidx ) and vim.fn.getcwd( windownr, tabidx ) or vim.fn.haslocaldir( -1, tabidx ) and vim.fn.getcwd( -1, tabidx) or vim.fn.getcwd())

            -- find the "project root" from the cwd, for now look for .git
            -- TODO - allow a user to configure how we find the project root
            --local git_root = vim.fn.systemlist("git -C " .. cwd .. " rev-parse --show-toplevel")[1]
            --local git_root = require('lspconfig.util').root_pattern(".git")(cwd)
            git_root =  root_pattern(cwd, '%.git$')

            local project_root = vim.fn.expand( opts.project_root or git_root or cwd)
            -- include the parent directory of the .git file
            project_root = project_root:gsub('[^/]+/?$', '')


            -- split the path
            -- path_start - from the project_root to the cwd, including the name 
            -- path_end - from the cwd to the file

            --local path_start = path.normalize( cwd, project_root:gsub ('[^/]+/?$', '') )
            local path_start = path.normalize( cwd, project_root )
            local info = vim.fn.getbufinfo(bufnr)[1]
            local path_end = path.normalize(info.name, cwd) or ''


            local element = {
                path_start = path_start,
                path_end = path_end,
                tabnr = tabnr,
                tabidx = tabidx,
                windownr = windownr,
                windowid = windowid,
                info = info
            }
            table.insert(windows, element)
        end
    end

  pickers.new(opts, {
    prompt_title = 'Tabs',
    finder    = finders.new_table {
      results = windows,
      entry_maker = opts.entry_maker or make_entry(opts)
    },
    sorter = sorters.get_fzy_sorter(opts),
      attach_mappings = function(_, map)
        -- use our custom action to go the window id
        map( 'i', '<CR>', goto_window)
        map( 'n', '<CR>', goto_window)
        return true
        end,
    default_selection_index = selection_idx,
  }):find()
end



--[[
-- this is based on make_entry.gen_from_buffer
-- ]]

function make_entry(_)
  opts = opts or {}

  local disable_devicons = opts.disable_devicons

  local icon_width = 0
  if not disable_devicons then
    local icon, _ = utils.get_devicons('fname', disable_devicons)
    icon_width = utils.strdisplaywidth(icon)
  end


  local make_display = function(entry)


    --[[
    -- for now not using the option to shorten_path
    -- should allow this to give enough space for a vetical previewer
    local display_bufname
    if opts.shorten_path then
      display_bufname = path.shorten(entry.filename)
    else
      display_bufname = entry.filename
    end
    -- ]]

      --[[
      -- IMPORTANT the lua library string formatter only allows strings up to 99 characters
      -- make sure entry.path_start is not longer than 99 characters or the code will fail
      -- ]]
      local displayer = entry_display.create {
        separator = "",
        items = {
          --{ width = opts.bufnr_width },
          { width = 2 },
          { width = 5 },
          { width = (icon_width + 3) },
          { width = string.len( entry.path_start ) },
          { width = 1 },
          { remaining = true },
        },
      }

    local icon, hl_group = utils.get_devicons(entry.filename, disable_devicons)

    --[[ Using the hl_group from the devicons to color the end
    -- of the path which ncludes the filename
    -- this will not suit everyone, make an option to disable
    -- ]]

    local path_end_highlight = state.use_highlighter and hl_group or nil
    return displayer {
      { entry.tabidx, "TelescopeResultsNumber"},
      { entry.indicator, "TelescopeResultsComment"},
      { icon, hl_group },
      { entry.path_start },
      { '/', "TelescopeResultsNumber" },
      { entry.path_end, path_end_highlight },
      }
  end

  return function(entry)
    local filename = entry.info.name

    --[[
    -- Tese come from the buffer picker, not sure if we need them
    -- but shwoing a window has an edited buffer is useful
    -- ]]
    local hidden = entry.info.hidden == 1 and 'h' or 'a'
    local readonly = vim.api.nvim_buf_get_option(entry.bufnr, 'readonly') and '=' or ' '
    local changed = entry.info.changed == 1 and '+' or ' '
    local indicator = entry.windownr .. hidden .. readonly .. changed

    return {
      valid = true,
      path_start = entry.path_start,
      path_end = entry.path_end,

      value = entry.windowid,
      display = make_display,
      ordinal = entry.tabidx .. " : " .. entry.windownr .. " : " .. entry.path_start .. '/' .. entry.path_end,

      tabnr = entry.tabnr,
      tabidx = entry.tabidx,
      windownr = entry.windownr,
      filename = filename,

      lnum = entry.info.lnum ~= 0 and entry.info.lnum or 1,
      indicator = indicator,
    }
  end
end

local function set_config_state(opt_name, value, default)
  state[opt_name] = value == nil and default or value
end


return telescope.register_extension {
  setup = function(ext_config)
  set_config_state('project_root', ext_config.project_root, '.git')
  set_config_state('use_highlighter', ext_config.use_highlighter, true)
  end,
  exports = {
    list = list,
  }
}
