return {
  {
    "nvim-mini/mini.snippets",
    opts = function(_, opts)
      local gen_loader = require("mini.snippets").gen_loader
      opts.snippets = opts.snippets or {}
      vim.list_extend(opts.snippets, {
        gen_loader.from_file("~/.config/nvim/snippets/global.json"),
        gen_loader.from_lang(),
      })
      return opts
    end,
  },
}
