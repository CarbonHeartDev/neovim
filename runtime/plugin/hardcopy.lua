if vim.g.loaded_hardcopy then
  return
end
vim.g.loaded_hardcopy = 1

local function export_to_html_and_open_output(params)
  vim.pretty_print(params)
  local range = params.range ~= 0 and {params.line1, params.line2} or {}
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
        vim.api.nvim_err_writeln('"' .. default_directory .. '" is not a valid default directory, cancelling.')
        return
      end
      path = vim.g.hardcopy_default_directory
    else
      path = vim.loop.fs_stat(vim.fn.expand('~/Downloads/')) and vim.fn.expand('~/Downloads/') or vim.fn.tempname()
    end
    -- Add filename
    path = path .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':p:t')
    vim.pretty_print(path)
    -- Add range at end of filename if specified
    if params.range > 0 then
      path = path .. '(L' .. params.line1 .. (params.range > 1 and '-' .. params.line2 or '') .. ')'
    end
  end

  vim.cmd.TOhtml({ range = range })
  local tohtml_bufnr = vim.api.nvim_win_get_buf(0)

  path = vim.fn.fnameescape(path .. '.html')
  vim.api.nvim_buf_set_name(tohtml_bufnr, path)
  if vim.loop.fs_stat(path) and not params.bang then
    local choice = vim.fn.confirm(
      'A .html file with the same name exists. Continue and overwrite? (Default: No)',
      '&Yes\n&No',
      2,
      'Question'
    )
    if choice ~= 1 then
      vim.cmd.bwipeout({bang = true, args = { tohtml_bufnr }})
      return
    end
  end
  vim.cmd.wq({bang = true, args = {path}})
  vim.notify('Saved HTML at: ' .. path)

  vim.fn['netrw#BrowseX'](path, 0)

  vim.cmd.bwipeout({bang = true, args = { tohtml_bufnr }})
end

vim.api.nvim_create_user_command('Hardcopy', export_to_html_and_open_output, {
  desc = 'Dumps the buffer content into an HTML and opens the browser for viewing or printing',
  nargs = '?',
  range = true,
  bang = true,
  complete = 'file',
})
