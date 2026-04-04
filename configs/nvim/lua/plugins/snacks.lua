return {
  "folke/snacks.nvim",
  opts = {
    explorer = {
      replace_netrw = true,
    },
  },
  keys = {
    {
      "<leader>e",
      function()
        Snacks.explorer({ root = false })
      end,
      desc = "Explorer Snacks (CWD)",
    },
    {
      "<leader>fE",
      function()
        Snacks.explorer({ root = true })
      end,
      desc = "Explorer Snacks (Root Dir)",
    },
  },
}
