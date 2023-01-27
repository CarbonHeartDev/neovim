if vim.g.loaded_hardcopy then
  return
end
vim.g.loaded_hardcopy = 1

--- This function check if the system on which Neovim is running offers to Neovim a command to open
--- files, this is needed by the extension to decide if convert the buffer to HTML and send to a
--- browser or use a fallback printing/exporting system
--- @return boolean
local function test_netrw_BrowseX()
  if vim.g.netrw_browsex_viewer ~= nil then
    -- If the user manually configured netrw_browsex_viewer the function trusts his configuration
    -- and avoids any further check

    -- Check if specific handler for HTML exists?

    return true
  else
    if vim.fn.has('win32') ~= 0 then
      -- Almost any version of Windows is shipped with a browser allowing the viewing of HTML files,
      -- the only exception is Windows Server Core (TODO: handle and test the case on virtual
      -- machine) and Windows Nano Server which is made to run just on containers and may not
      -- support Neovim at all (TODO: verify this assumption)
      return true
    elseif vim.fn.has('unix') ~= 0 then
      if vim.loop.os_uname().sysname == "Darwin" then
        -- macOS always has a full GUI and a browser... even on servers
        return true
      else
        -- Check if one of the default programs used by Netrw to open files exists
        return vim.fn.system('which xdg-open') ~= "" or
          vim.fn.system('which gnome-open') ~= "" or
          vim.fn.system('which kfmclient') ~= ""
      end
    else
      return false
    end
  end
end

--- Exports the content of the current buffer to an HTML file and tries
--- to open it in a browser for printing or exporting to other file formats
---@param range table the range to export
---@param path string output file path
---@param overwrite boolean if a file already exists in the same path overwrite without asking
local function export_to_html_and_open_output(range, path, overwrite)
  vim.cmd.TOhtml({ range = range })
  local tohtml_bufnr = vim.api.nvim_get_current_buf()

  path = vim.fn.fnameescape(path .. '.html')
  vim.api.nvim_buf_set_name(tohtml_bufnr, path)
  if vim.loop.fs_stat(path) and not overwrite then
    local choice = vim.fn.confirm(
      'A .html file with the same name exists. Continue and overwrite? (Default: No)',
      '&Yes\n&No',
      2,
      'Question'
    )
    if choice ~= 1 then
      vim.cmd.bwipeout({ bang = true, args = { tohtml_bufnr } })
      return
    end
  end
  vim.cmd.wq({ bang = true, args = { path } })
  vim.notify('Saved HTML at: ' .. path)

  vim.fn['netrw#BrowseX'](path, 0)

  vim.cmd.bwipeout({ bang = true, args = { tohtml_bufnr } })
end

local function unix_fallback_printing_system()

  -- Todo: add check to see if the system supports fallback printing

  local function parse_raw_printer_list(lpstat_output)
    local printer_names = {}
    for match in string.gmatch(lpstat_output, " [^ /#]+: ") do
      local printer_name = string.sub(match, 2, -3)
      table.insert(printer_names, printer_name)
    end

    return printer_names
  end

  local raw_printer_list = vim.fn.system('lpstat -v')
  local parsed_printer_list = parse_raw_printer_list(raw_printer_list)
  
  error("Not yet implemented")

end

--- Stub for printing/exporting systems which are going to be used when Netrw cannot open a valid
--- HTML viewer on the system
local function print_or_export_with_the_fallback_systems()
  if vim.fn.has('win32') ~= 0 then
    error("Fallback printing not implemented for Windows")
  elseif vim.fn.has('unix') ~= 0 then
    error("Fallback printing not implemented for unix")
  else
    error("Fallback printing not implemented for the current system")
  end
end

vim.api.nvim_create_user_command('Hardcopy', function(cmd)

  local range = params.range ~= 0 and { params.line1, params.line2 } or {}

  local path = ''
  if #params.args > 0 then
    local stats = vim.loop.fs_stat(params.args)
    if stats and stats.type == 'directory' then
      vim.api.nvim_err_writeln([[E502: "]] .. params.args .. [[" is a directory]])
      return
    end
    path = vim.fn.expand(params.args)
  else
    if vim.g.hardcopy_default_directory then
      local default_directory = vim.fn.expand(vim.g.hardcopy_default_directory)
      local stats = vim.loop.fs_stat(default_directory)
      if not stats or stats.type ~= 'directory' then
        vim.api.nvim_err_writeln(
          '"' .. default_directory .. '" is not a valid default directory, cancelling.'
        )
        return
      end
      path = default_directory
    else
      path = vim.loop.fs_stat(vim.fn.expand('~/Downloads/')) and vim.fn.expand('~/Downloads/')
        or vim.fn.tempname()
    end
    -- Add filename
    path = path .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':p:t')
    -- Add range at end of filename if specified
    if params.range > 0 then
      path = path .. '(L' .. params.line1 .. (params.range > 1 and '-' .. params.line2 or '') .. ')'
    end
  end

  -- Todo if test_netrw_BrowseX needs to be called each time Hardcopy is invoked or running it at
  -- the extension loading is enough
  if test_netrw_BrowseX() and not force_fallback_printing then
    export_to_html_and_open_output(range, path, cmd.bang)
  else
    print_or_export_with_the_fallback_systems()
  end
end, {
  desc = 'Dumps the buffer content into an HTML and opens the browser for viewing or printing',
  nargs = '?',
  range = true,
  bang = true,
  complete = 'file',
})
