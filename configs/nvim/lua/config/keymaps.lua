-- This file contains custom key mappings for Neovim.

-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Map Ctrl+b in insert mode to delete to the end of the word without leaving insert mode
vim.keymap.set("i", "<C-b>", "<C-o>de")

-- Map Ctrl+c to escape from other modes
vim.keymap.set({ "i", "n", "v" }, "<C-c>", [[<C-\><C-n>]])

local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  if #lines == 0 then
    return nil
  end

  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
  else
    lines[1] = string.sub(lines[1], start_pos[3])
    lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  end

  return table.concat(lines, "\n")
end

local function grep_selected_text(opts)
  local selected_text = get_visual_selection()
  if not selected_text then
    return
  end

  selected_text = vim.fn.escape(selected_text, "\\.*[]^$()+?{}")

  if pcall(require, "snacks") then
    require("snacks").picker.grep(vim.tbl_extend("force", { search = selected_text }, opts or {}))
  elseif pcall(require, "fzf-lua") then
    require("fzf-lua").live_grep(vim.tbl_extend("force", { search = selected_text }, opts or {}))
  else
    vim.notify("No grep picker available", vim.log.levels.ERROR)
  end
end

local function save_file()
  if vim.fn.empty(vim.fn.expand("%:t")) == 1 then
    vim.notify("No file to save", vim.log.levels.WARN)
    return
  end

  local filename = vim.fn.expand("%:t")
  local success, err = pcall(function()
    vim.cmd("silent! write")
  end)

  if success then
    vim.notify(filename .. " Saved!")
  else
    vim.notify("Error: " .. err, vim.log.levels.ERROR)
  end
end

-- Delete all buffers but the current one
vim.keymap.set(
  "n",
  "<leader>bq",
  '<Esc>:%bdelete|edit #|normal`"<Return>',
  { desc = "Delete other buffers but the current one" }
)

-- Disable key mappings in insert mode
vim.keymap.set("i", "<A-j>", "<Nop>", { silent = true })
vim.keymap.set("i", "<A-k>", "<Nop>", { silent = true })

-- Disable key mappings in normal mode
vim.keymap.set("n", "<A-j>", "<Nop>", { silent = true })
vim.keymap.set("n", "<A-k>", "<Nop>", { silent = true })

-- Disable key mappings in visual block mode
vim.keymap.set("x", "<A-j>", "<Nop>", { silent = true })
vim.keymap.set("x", "<A-k>", "<Nop>", { silent = true })
vim.keymap.set("x", "J", "<Nop>", { silent = true })
vim.keymap.set("x", "K", "<Nop>", { silent = true })

-- Redefine Ctrl+s to save with the custom function
vim.keymap.set("n", "<C-s>", save_file, { desc = "Save file", silent = true })

-- Grep keybinding for visual mode - search selected text
vim.keymap.set("v", "<leader>sg", function()
  grep_selected_text()
end, { desc = "Grep Selected Text" })

-- Grep keybinding for visual mode with G - search selected text at root level
vim.keymap.set("v", "<leader>sG", function()
  local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
  local root = vim.v.shell_error == 0 and git_root ~= "" and git_root or vim.fn.getcwd()
  grep_selected_text({ cwd = root })
end, { desc = "Grep Selected Text (Root Dir)" })

-- Delete all marks
vim.keymap.set("n", "<leader>md", function()
  vim.cmd("delmarks!")
  vim.cmd("delmarks A-Z0-9")
  vim.notify("All marks deleted")
end, { desc = "Delete all marks" })

-- Format on demand with Shift+Option+F
vim.keymap.set({ "n", "v" }, "<M-F>", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer" })
