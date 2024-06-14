local M = {}

M.sub_commands = {
    {
        name = "base64_decode",
        get_result = function(text)
            return M.process_base64_decode(text)
        end
    },
    {
        name = "base64_encode",
        get_result = function(text)
            return M.process_base64_encode(text)
        end
    }
}

-- Function to provide completion for sub-commands
function M.complete_subcommands(arg_lead, cmd_line, cursor_pos)
    local filtered_commands = vim.tbl_filter(function(item)
        -- vim.print('"' .. arg_lead .. '"')
        -- return true
        return vim.startswith(item.name, arg_lead)
    end, M.sub_commands)

    return vim.tbl_map(function(item)
        return item.name
    end, filtered_commands)
end

-- Function to get the visual selection
function M.get_visual_selection()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local start_line = start_pos[2]
    local start_col = start_pos[3]
    local end_line = end_pos[2]
    local end_col = end_pos[3]

    if start_line == end_line then
        local line = vim.fn.getline(start_line)
        return string.sub(line, start_col, end_col)
    else
        local lines = vim.fn.getline(start_line, end_line)
        lines[1] = string.sub(lines[1], start_col)
        lines[#lines] = string.sub(lines[#lines], 1, end_col)
        return table.concat(lines, "\n")
    end
end

function M.process_command(cmd)
    if cmd.nargs == 0 then
        vim.print("No subcommand specified")
        return
    end

    local text = M.get_visual_selection()
    for _, val in pairs(M.sub_commands) do
        if val.name == cmd.args then
            local result = val.get_result(text)
            vim.fn.setreg('"', result)
            return
        end
    end

    vim.print("Invalid command " .. cmd.args)
end

function M.process_base64_encode(text)
    vim.print("process_base64_encode")
    local base64 = require("text-power-tools.base64")

    local result = base64.encode(text)
    return result
end

function M.process_base64_decode(text)
    vim.print("process_base64_encode")
    local base64 = require("text-power-tools.base64")

    local result = base64.decode(text)
    return result
end

function M.telescope()
    local status, _ = pcall(require, "telescope")

    if not status then
        print("You need to install telescope.nvim")
        return
    end

    local pickers = require "telescope.pickers"
    local finders = require "telescope.finders"
    local previewers = require('telescope.previewers')
    local actions = require "telescope.actions"
    local action_state = require "telescope.actions.state"
    local conf = require("telescope.config").values

    local text = M.get_visual_selection()
    local picker = function(opts)
        opts = opts or {}

        local results = {}
        for _, val in pairs(M.sub_commands) do
            local status, result = pcall(val.get_result, text)
            local final_result = ""
            if status then
                final_result = result
            end

            table.insert(
                results,
                {
                    name = val.name,
                    result = final_result,
                    successful = status
                }
            )
        end

        pickers.new(opts, {
            prompt_title = "colors",
            sorter = conf.generic_sorter(opts),
            finder = finders.new_table {
                results = results,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = entry.name,
                        ordinal = entry.name,
                        preview = 'Result for:\n' .. text .. '\n\nis:\n' .. entry.result,
                        result = entry.result,
                        successful = entry.successful
                    }
                end
            },
            previewer = previewers.new_buffer_previewer {
                define_preview = function(self, entry, status)
                    if not entry.successful then
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "Could not calculate" })
                    else
                        local lines = vim.split(entry.preview, "\n")
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                    end
                end
            },
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    vim.fn.setreg('"', selection.result)
                end)
                return true
            end,
        }):find()
    end

    picker()
end

function M.setup()
    -- vim.api.nvim_out_write("Hello from my Lua plugin!\n")

    vim.api.nvim_create_user_command(
        'TextPowerTool',
        M.process_command,
        {
            nargs = 1,
            complete = M.complete_subcommands,
            range = true,
        })

    vim.api.nvim_create_user_command(
        'TextPowerToolTelescope',
        M.telescope,
        {
            nargs = 0,
            range = true,
        }
    )
end

return { setup = M.setup, telescope = M.telescope }
