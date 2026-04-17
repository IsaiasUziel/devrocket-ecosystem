-- This file contains the configuration for the nvim-tmux-navigation plugin in Neovim.

return {
  -- Plugin: nvim-tmux-navigation
  -- URL: https://github.com/alexghergh/nvim-tmux-navigation
  -- Description: A Neovim plugin that allows seamless navigation between Neovim and tmux panes.
  "alexghergh/nvim-tmux-navigation",
  keys = {
    { "<C-h>", function() require("nvim-tmux-navigation").NvimTmuxNavigateLeft() end, desc = "Navigate left pane" },
    { "<C-j>", function() require("nvim-tmux-navigation").NvimTmuxNavigateDown() end, desc = "Navigate bottom pane" },
    { "<C-k>", function() require("nvim-tmux-navigation").NvimTmuxNavigateUp() end, desc = "Navigate top pane" },
    { "<C-l>", function() require("nvim-tmux-navigation").NvimTmuxNavigateRight() end, desc = "Navigate right pane" },
    { "<C-\\>", function() require("nvim-tmux-navigation").NvimTmuxNavigateLastActive() end, desc = "Navigate last pane" },
    { "<C-Space>", function() require("nvim-tmux-navigation").NvimTmuxNavigateNext() end, desc = "Navigate next pane" },
  },
}
