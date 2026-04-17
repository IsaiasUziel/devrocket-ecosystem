-- This file contains the configuration for the which-key.nvim plugin in Neovim.

return {
  "folke/which-key.nvim",

  event = "VeryLazy",
  opts = {
    preset = "classic",
    win = {
      border = "single",
    },
  },

  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)

    wk.add({
      { "<leader>o", group = "Obsidian" },
      { "<leader>e", group = "Explorer" },
    })
  end,

  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Keymaps (which-key)",
    },
  },
}
