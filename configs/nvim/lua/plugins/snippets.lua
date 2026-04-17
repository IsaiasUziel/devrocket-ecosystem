return {
  {
    "nvim-mini/mini.snippets",
    opts = function(_, opts)
      local gen_loader = require("mini.snippets").gen_loader
      opts.snippets = opts.snippets or {}
      vim.list_extend(opts.snippets, {
        gen_loader.from_file("~/.config/nvim/snippets/global.json"),
        gen_loader.from_lang({
          lang_patterns = {
            -- Prevent framework snippets (Angular, Vue, etc.) from leaking
            -- into other filetypes via Treesitter language injection.
            -- Default `**/xxx.json` pattern matches across subdirectories,
            -- e.g. `**/html.json` matches `frameworks/angular/html.json`.
            html = { 'html/**/*.json', 'html.json' },
            css = { 'css/**/*.json', 'css.json' },
            javascript = { 'javascript/**/*.json', 'javascript/**/*.lua' },
            typescript = { 'typescript/**/*.json', 'typescript/**/*.lua' },
          },
        }),
      })
      return opts
    end,
  },
}
