-- PHP + WordPress profile for LazyVim.
--
-- Auto-activates when the project has composer.json or phpcs.xml.
-- Provides: phpactor LSP, PHPCS diagnostics, and PHPCBF formatting aligned
-- with the project's Composer scripts.
--
-- This file is imported directly from lua/plugins/ (not via .lazy.lua).

local function is_php_project()
  return vim.fn.filereadable("composer.json") == 1
    or vim.fn.filereadable("phpcs.xml") == 1
    or vim.fn.filereadable("phpcs.xml.dist") == 1
end

-- Early exit: return empty specs if not a PHP project.
if not is_php_project() then
  return {}
end

local function ensure_item(list, value)
  if not vim.tbl_contains(list, value) then
    table.insert(list, value)
  end
end

local function resolve_search_path(path)
  if not path or path == "" then
    return vim.fn.getcwd()
  end

  if vim.fn.isdirectory(path) == 1 then
    return path
  end

  return vim.fs.dirname(path)
end

local function find_project_executable(path, executable)
  local start = resolve_search_path(path)
  local vendor_bin = vim.fs.find({ "vendor" }, { upward = true, path = start, limit = math.huge })

  for _, vendor in ipairs(vendor_bin) do
    local candidate = vim.fs.joinpath(vendor, "bin", executable)
    if vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end

  local mason = vim.fn.expand("~/.local/share/nvim/mason/bin/" .. executable)
  if vim.fn.executable(mason) == 1 then
    return mason
  end

  return executable
end

local function find_node_executable(path, executable)
  local start = resolve_search_path(path)
  local isolated_tool = vim.fn.expand("~/.config/nvim/.tools/blade-formatter/node_modules/.bin/" .. executable)

  if vim.fn.executable(isolated_tool) == 1 then
    return isolated_tool
  end

  local node_modules = vim.fs.find({ "node_modules" }, { upward = true, path = start, limit = math.huge })

  for _, directory in ipairs(node_modules) do
    local candidate = vim.fs.joinpath(directory, ".bin", executable)
    if vim.fn.executable(candidate) == 1 then
      return candidate
    end
  end

  if vim.fn.executable(executable) == 1 then
    return executable
  end

  return nil
end

local function is_wordpress_template_file(path)
  local normalized = vim.fs.normalize(path or "")
  local basename = vim.fs.basename(normalized)
  local root_templates = {
    ["404.php"] = true,
    ["archive.php"] = true,
    ["attachment.php"] = true,
    ["author.php"] = true,
    ["category.php"] = true,
    ["comments.php"] = true,
    ["date.php"] = true,
    ["footer.php"] = true,
    ["front-page.php"] = true,
    ["header.php"] = true,
    ["home.php"] = true,
    ["index.php"] = true,
    ["page.php"] = true,
    ["search.php"] = true,
    ["sidebar.php"] = true,
    ["single.php"] = true,
    ["singular.php"] = true,
    ["tag.php"] = true,
    ["taxonomy.php"] = true,
  }

  if root_templates[basename] then
    return true
  end

  return normalized:match("/templates?/") ~= nil
    or normalized:match("/template%-parts/") ~= nil
    or normalized:match("/parts/") ~= nil
end

local function find_phpcs_standard(path)
  local standard = vim.fs.find({ "phpcs.xml", "phpcs.xml.dist" }, {
    path = resolve_search_path(path),
    upward = true,
  })[1]
  return standard and vim.fs.normalize(standard) or nil
end

local php_wordpress_group = vim.api.nvim_create_augroup("php-wordpress-profile", { clear = true })

-- Keep PHP editing sane in mixed PHP/HTML templates.
-- We only disable Tree-sitter indent for PHP buffers; syntax highlighting remains intact.
vim.api.nvim_create_autocmd("FileType", {
  group = php_wordpress_group,
  pattern = "php",
  desc = "Disable Tree-sitter indentexpr for PHP buffers",
  callback = function(event)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(event.buf) then
        vim.bo[event.buf].indentexpr = ""
        vim.bo[event.buf].smartindent = false
        vim.bo[event.buf].cindent = false
        vim.bo[event.buf].autoindent = true
      end
    end)
  end,
})

return {
  -- LSP: phpactor
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        phpactor = { enabled = true },
      },
    },
  },

  -- Mason: install PHPCS + PHPCBF (not php-cs-fixer).
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      ensure_item(opts.ensure_installed, "phpcs")
      ensure_item(opts.ensure_installed, "phpcbf")
    end,
  },

  -- Linter: PHPCS diagnostics for PHP files.
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.php = { "phpcs" }

      opts.linters = opts.linters or {}
      opts.linters.phpcs = vim.tbl_deep_extend("force", opts.linters.phpcs or {}, {
        cmd = function()
          return find_project_executable(vim.api.nvim_buf_get_name(0), "phpcs")
        end,
        args = function()
          local args = { "--report=json" }
          local filename = vim.api.nvim_buf_get_name(0)
          local standard = find_phpcs_standard(filename)

          if standard then
            table.insert(args, "--standard=" .. standard)
          end

          table.insert(args, "--stdin-path=" .. filename)
          table.insert(args, "-")
          return args
        end,
      })
    end,
  },

  -- Formatter: PHPCBF aligned with the project's composer lint:fix command.
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.php = { "blade_formatter_php", "phpcbf_project", stop_after_first = true }

      local previous_format_on_save = opts.format_on_save
      opts.format_on_save = function(bufnr)
        if vim.bo[bufnr].filetype == "php" then
          return {
            timeout_ms = 5000,
            lsp_format = "never",
          }
        end

        if type(previous_format_on_save) == "function" then
          return previous_format_on_save(bufnr)
        end

        return previous_format_on_save
      end

      opts.formatters = opts.formatters or {}
      opts.formatters.blade_formatter_php = {
        command = function(_, ctx)
          return find_node_executable(ctx.filename, "blade-formatter")
        end,
        args = { "--stdin", "--php-version", "8.2" },
        stdin = true,
        cwd = function(_, ctx)
          return resolve_search_path(ctx.filename)
        end,
        condition = function(_, ctx)
          return is_wordpress_template_file(ctx.filename)
            and find_node_executable(ctx.filename, "blade-formatter") ~= nil
        end,
      }

      opts.formatters.phpcbf_project = {
        command = function(_, ctx)
          return find_project_executable(ctx.filename, "phpcbf")
        end,
        args = function(_, ctx)
          local standard = find_phpcs_standard(ctx.filename)
          local args = {}

          if standard then
            table.insert(args, "--standard=" .. standard)
          end

          table.insert(args, ctx.filename)

          return args
        end,
        stdin = false,
        cwd = function(_, ctx)
          return resolve_search_path(ctx.filename)
        end,
        tmpfile_format = "conform.$RANDOM.$FILENAME",
        exit_codes = { 0, 1, 2 },
        condition = function(_, ctx)
          return vim.fn.filereadable(ctx.filename) == 1
        end,
      }
    end,
  },
}
