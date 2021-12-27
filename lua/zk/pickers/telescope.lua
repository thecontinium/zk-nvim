local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local action_utils = require("telescope.actions.utils")
local putils = require("telescope.previewers.utils")
local entry_display = require("telescope.pickers.entry_display")
local previewers = require("telescope.previewers")

local M = {}

M.note_picker_list_api_selection = { "title", "absPath", "rawContent" }

function M.create_note_entry_maker(_)
  return function(note)
    return {
      value = note,
      path = note.absPath,
      display = note.title,
      ordinal = note.title,
    }
  end
end

function M.create_tag_entry_maker(opts)
  return function(tag)
    local displayer = entry_display.create({
      separator = " ",
      items = {
        { width = opts.note_count_width or 4 },
        { remaining = true },
      },
    })
    local make_display = function(e)
      return displayer({
        { e.value.note_count, "TelescopeResultsNumber" },
        e.value.name,
      })
    end
    return {
      value = tag,
      display = make_display,
      ordinal = tag.name,
    }
  end
end

function M.make_note_previewer()
  return previewers.new_buffer_previewer({
    define_preview = function(self, entry)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, vim.split(entry.value.rawContent, "\n"))
      putils.highlighter(self.state.bufnr, "markdown")
    end,
  })
end

function M.show_note_picker(notes, options, action)
  options = options or {}
  local telescope_options = vim.tbl_extend("force", { prompt_title = options.title }, options.telescope or {})

  local attach_mappings
  if action == "edit" then
    attach_mappings = nil
  else
    assert(type(action) == "function", "action must be a function")
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        if options.multi_select then
          local selection = {}
          action_utils.map_selections(prompt_bufnr, function(entry, _)
            table.insert(selection, entry.value.name)
          end)
          if vim.tbl_isempty(selection) then
            selection = { action_state.get_selected_entry().value }
          end
          actions.close(prompt_bufnr)
          action(selection)
        else
          actions.close(prompt_bufnr)
          action(action_state.get_selected_entry().value)
        end
      end)
      return true
    end
  end

  pickers.new(telescope_options, {
    finder = finders.new_table({
      results = notes,
      entry_maker = M.create_note_entry_maker(options),
    }),
    sorter = conf.file_sorter(options),
    previewer = M.make_note_previewer(),
    attach_mappings = attach_mappings,
  }):find()
end

function M.show_tag_picker(tags, options, cb)
  options = options or {}
  local telescope_options = vim.tbl_extend("force", { prompt_title = options.title }, options.telescope or {})

  pickers.new(telescope_options, {
    finder = finders.new_table({
      results = tags,
      entry_maker = M.create_tag_entry_maker(options),
    }),
    sorter = conf.generic_sorter(options),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        if options.multi_select then
          local selection = {}
          action_utils.map_selections(prompt_bufnr, function(entry, _)
            table.insert(selection, entry.value)
          end)
          if vim.tbl_isempty(selection) then
            selection = { action_state.get_selected_entry().value }
          end
          actions.close(prompt_bufnr)
          cb(selection)
        else
          cb(action_state.get_selected_entry().value)
        end
      end)
      return true
    end,
  }):find()
end

return M