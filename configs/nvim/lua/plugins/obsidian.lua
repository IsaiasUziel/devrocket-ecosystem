return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- recommended, use latest release instead of latest commit
  lazy = false,
  enabled = function()
    -- Allow disabling Obsidian from an external global flag when needed.
    return not vim.g.disable_obsidian
  end,
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",
  },
  keys = {
    { "<leader>oc", "<cmd>Obsidian check<CR>", desc = "Obsidian check checkbox" },
    { "<leader>ot", "<cmd>Obsidian template<CR>", desc = "Insert Obsidian template" },
    { "<leader>oo", "<cmd>Obsidian open<CR>", desc = "Open in Obsidian app" },
    { "<leader>ob", "<cmd>Obsidian backlinks<CR>", desc = "Show Obsidian backlinks" },
    { "<leader>ol", "<cmd>Obsidian links<CR>", desc = "Show Obsidian links" },
    { "<leader>on", "<cmd>Obsidian new<CR>", desc = "Create new note" },
    { "<leader>os", "<cmd>Obsidian search<CR>", desc = "Search Obsidian" },
    { "<leader>oq", "<cmd>Obsidian quick-switch<CR>", desc = "Quick switch" },
  },
  opts = {
    legacy_commands = false,
    workspaces = {
      {
        name = "devRocketNotes", -- Name of the workspace
        path = os.getenv("HOME") .. "/.config/obsidian", -- Path to the notes directory
      },
    },
    completion = {
      cmp = true,
    },
    picker = {
      -- Set your preferred picker. Can be one of 'telescope.nvim', 'fzf-lua', 'mini.pick' or 'snacks.pick'.
      name = "snacks.pick",
    },
    -- Optional, define your own callbacks to further customize behavior.
    callbacks = {
      -- Runs anytime you enter the buffer for a note.
      -- NOTE: Breaking change in obsidian.nvim - callback now receives only (note), not (client, note)
      enter_note = function(note)
        if not note then
          return
        end
        -- Setup keymaps for obsidian notes
        vim.keymap.set("n", "gf", function()
          return require("obsidian").util.gf_passthrough()
        end, { buffer = note.bufnr, expr = true, desc = "Obsidian follow link" })

        vim.keymap.set("n", "<leader>ch", function()
          return require("obsidian").util.toggle_checkbox()
        end, { buffer = note.bufnr, desc = "Toggle checkbox" })

        vim.keymap.set("n", "<cr>", function()
          return require("obsidian").util.smart_action()
        end, { buffer = note.bufnr, expr = true, desc = "Obsidian smart action" })
      end,
    },

    -- Settings for templates
    templates = {
      subdir = "templates", -- Subdirectory for templates
      date_format = "%Y-%m-%d-%a", -- Date format for templates
      gtime_format = "%H:%M", -- Time format for templates
      tags = "", -- Default tags for templates
    },
  },
}
