return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
  {
    "saghen/blink.cmp",
    lazy = true,
    dependencies = { "saghen/blink.compat", "windwp/nvim-autopairs" },
    opts = {
      snippets = { preset = "mini_snippets" },
      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
          window = {
            border = "rounded",
          },
        },
        ghost_text = {
          enabled = true,
        },
        menu = {
          border = "rounded",
          draw = {
            columns = {
              { "kind_icon" },
              { "label", "label_description", gap = 1 },
              { "source_name" },
            },
          },
        },
        trigger = {
          show_on_trigger_character = true,
          show_on_accept = false,
        },
      },
      signature = {
        enabled = true,
        window = {
          border = "rounded",
        },
      },
      sources = {
        default = { "lsp", "snippets", "path", "buffer" },
        providers = {
          lsp = {
            name = "lsp",
            score_offset = 60,
            -- Filter Emmet suggestions in PHP strings to let Tailwind work
            transform_items = function(ctx, items)
              local ft = vim.bo[ctx.bufnr].filetype
              if ft == "php" or ft == "blade" then
                -- Check if cursor is inside a string using treesitter
                local ok, ts = pcall(require, "vim.treesitter")
                if ok then
                  local node = ts.get_node()
                  if node then
                    local node_type = node:type()
                    -- If cursor is in a string, filter out Emmet completions
                    if node_type == "string" or node_type == "string_content" then
                      return vim.tbl_filter(function(item)
                        -- Filter out Emmet abbreviations
                        return not (item.detail and item.detail:match("Emmet"))
                      end, items)
                    end
                  end
                end
              end
              return items
            end,
          },
        },
      },
      keymap = {
        preset = "default",
        ["<C-S-S>"] = { "show", "show_documentation", "hide_documentation" },
        ["<CR>"] = { "accept", "fallback" },
      },
    },
    opts_extend = { "sources.default" },
  },
}
