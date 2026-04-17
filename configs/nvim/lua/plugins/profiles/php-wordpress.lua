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
    ["comments-popup.php"] = true,
    ["date.php"] = true,
    ["embed.php"] = true,
    ["footer.php"] = true,
    ["front-page.php"] = true,
    ["header.php"] = true,
    ["home.php"] = true,
    ["index.php"] = true,
    ["page.php"] = true,
    ["privacy-policy.php"] = true,
    ["search.php"] = true,
    ["sidebar.php"] = true,
    ["single.php"] = true,
    ["singular.php"] = true,
    ["tag.php"] = true,
    ["taxonomy.php"] = true,
  }
  local template_patterns = {
    "^page%-.+%.php$",
    "^single%-.+%.php$",
    "^singular%-.+%.php$",
    "^archive%-.+%.php$",
    "^category%-.+%.php$",
    "^tag%-.+%.php$",
    "^taxonomy%-.+%.php$",
    "^author%-.+%.php$",
    "^date%-.+%.php$",
    "^home%-.+%.php$",
    "^front%-page%-.+%.php$",
    "^search%-.+%.php$",
    "^attachment%-.+%.php$",
    "^embed%-.+%.php$",
    "^section%-.+%.php$",
    "^component%-.+%.php$",
    "^block%-.+%.php$",
    "^hero%-.+%.php$",
    "^modal%-.+%.php$",
  }

  if root_templates[basename] then
    return true
  end

  for _, pattern in ipairs(template_patterns) do
    if basename:match(pattern) then
      return true
    end
  end

  return normalized:match("/templates?/") ~= nil
    or normalized:match("/template%-parts/") ~= nil
    or normalized:match("/parts/") ~= nil
    or normalized:match("/patterns/") ~= nil
    or normalized:match("/components/") ~= nil
    or normalized:match("/transient/") ~= nil
end

local function find_phpcs_standard(path)
  local standard = vim.fs.find({ "phpcs.xml", "phpcs.xml.dist" }, {
    path = resolve_search_path(path),
    upward = true,
  })[1]
  return standard and vim.fs.normalize(standard) or nil
end

--- Control keywords for WordPress alternative syntax.
local WP_CONTROL_OPEN = { "if", "elseif", "foreach", "for", "while", "switch" }
local WP_CONTROL_CLOSE_MAP = {
  endif = "if",
  endforeach = "foreach",
  endfor = "for",
  endwhile = "while",
  endswitch = "switch",
}

--- Fix WordPress template formatting patterns after external formatters run.
--- PASS 1: Collapses multi-line <?php keyword (...) : ?> to oneline.
--- PASS 2: Fixes <?php end*; ?> indentation to match opening structures.
---@param bufnr number Buffer number
---@return boolean Whether changes were made
local function fix_wp_template_patterns(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if not is_wordpress_template_file(filename) then
    return false
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local changed = false

  -- PASS 1: Collapse multi-line PHP control-structure openers to oneline.
  --
  -- 3-line pattern:
  --   <indent><?php
  --   <indent>keyword (condition) :
  --   <indent>?>
  --   → <indent><?php keyword (condition) : ?>
  --
  -- 2-line pattern:
  --   <indent><?php keyword (condition) :
  --   <indent>?>
  --   → <indent><?php keyword (condition) : ?>

  local collapsed = {}
  local i = 1

  while i <= #lines do
    local line = lines[i]
    local did_collapse = false

    -- Try 3-line collapse: <?php \n keyword(...) : \n ?>
    local php_indent = line:match("^(%s*)<%?php%s*$")
    if php_indent and i + 2 <= #lines then
      local next_line = lines[i + 1]
      local close_line = lines[i + 2]

      if close_line:match("^%s*%?>%s*$") then
        -- Strip leading/trailing whitespace from the control line
        local stripped = next_line:match("^%s*(.+)%s*$")
        if stripped then
          local is_alt_syntax = false
          for _, kw in ipairs(WP_CONTROL_OPEN) do
            if stripped:match("^" .. kw .. "%s*[%(]") then
              is_alt_syntax = true
              break
            end
          end
          -- Also handle else: (no condition)
          if not is_alt_syntax and stripped:match("^else%s*:") then
            is_alt_syntax = true
          end

          if is_alt_syntax then
            -- Normalize: trim trailing colon+spaces, add " :"
            local content = stripped:gsub("%s*:%s*$", "") .. " :"
            table.insert(collapsed, php_indent .. "<?php " .. content .. " ?>")
            changed = true
            i = i + 3
            did_collapse = true
          end
        end
      end
    end

    -- Try 2-line collapse: <?php keyword(...) : \n ?>
    if not did_collapse then
      local after_php = line:match("^%s*<%?php%s+(.+)%s*$")
      if after_php and not line:match("%?>%s*$") then
        -- Line has <?php and content but no closing ?>
        local is_alt_with_colon = false
        for _, kw in ipairs(WP_CONTROL_OPEN) do
          if after_php:match("^" .. kw .. "%s*[%(]") and after_php:match(":%s*$") then
            is_alt_with_colon = true
            break
          end
        end
        if not is_alt_with_colon and after_php:match("^else%s*:") then
          is_alt_with_colon = true
        end

        if is_alt_with_colon and i + 1 <= #lines and lines[i + 1]:match("^%s*%?>%s*$") then
          local line_indent = line:match("^(%s*)")
          local content = after_php:gsub("%s*:%s*$", "") .. " :"
          table.insert(collapsed, line_indent .. "<?php " .. content .. " ?>")
          changed = true
          i = i + 2
          did_collapse = true
        end
      end
    end

    if not did_collapse then
      table.insert(collapsed, line)
      i = i + 1
    end
  end

  -- PASS 2: Fix closing-tag indentation using a stack of opening structures.
  --
  -- Stack tracks: { keyword, indent }
  -- Opening  <?php keyword (...) : ?> → push
  -- Else/elseif                          → use top indent (don't push)
  -- Closing  <?php end*; ?>             → pop and apply indent

  local result = {}
  local stack = {}

  for _, line in ipairs(collapsed) do
    -- Check for opening control structure: <?php keyword (...) : ?>
    local line_indent = line:match("^([ \t]*)")
    local after_php = line:match("^%s*<%?php%s+(.+)%s*%?>")

    if after_php then
      -- Try opening keywords (push to stack)
      local pushed = false
      for _, kw in ipairs({ "if", "foreach", "for", "while", "switch" }) do
        if after_php:match("^" .. kw .. "%s*[%(]") then
          table.insert(stack, { keyword = kw, indent = line_indent })
          table.insert(result, line)
          pushed = true
          break
        end
      end

      if not pushed then
        -- Check for else / elseif (use top of stack, don't push)
        if after_php:match("^else%s*:") or after_php:match("^elseif%s*[%(]") then
          if #stack > 0 then
            local content = line:match("^%s*(.*)")
            local new_line = stack[#stack].indent .. content
            if new_line ~= line then
              changed = true
            end
            table.insert(result, new_line)
          else
            table.insert(result, line)
          end
          pushed = true
        end

        -- Check for closing: <?php endif; ?> etc.
        if not pushed then
          local close_kw = after_php:match("^(end%w+)%s*;")
          if close_kw then
            local expected = WP_CONTROL_CLOSE_MAP[close_kw]
            if expected and #stack > 0 then
              -- Search stack from top to find matching keyword
              local found_idx = nil
              for j = #stack, 1, -1 do
                if stack[j].keyword == expected then
                  found_idx = j
                  break
                end
              end

              if found_idx then
                local content = line:match("^%s*(.*)")
                local new_line = stack[found_idx].indent .. content
                if new_line ~= line then
                  changed = true
                end
                table.insert(result, new_line)
                -- Remove everything from found_idx to top
                for _ = found_idx, #stack do
                  table.remove(stack)
                end
              else
                -- No matching opening found — pass through unchanged
                table.insert(result, line)
              end
            else
              -- Unknown closing keyword or empty stack — pass through
              table.insert(result, line)
            end
          else
            -- Not a control structure line (variable assignment, echo, etc.)
            table.insert(result, line)
          end
        end
      end
    else
      -- Not a <?php ... ?> oneline line — pass through
      table.insert(result, line)
    end
  end

  if changed then
    -- Save cursor position
    local cursor_ok, cursor = pcall(vim.api.nvim_win_get_cursor, 0)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, result)
    if cursor_ok then
      local row = math.min(cursor[1], #result)
      pcall(vim.api.nvim_win_set_cursor, 0, { row, cursor[2] })
    end
    return true
  end

  return false
end

local function resolve_linter(name, bufnr)
  local ok, lint = pcall(require, "lint")
  if not ok then
    return nil
  end

  local linter = lint.linters[name]
  if type(linter) == "function" then
    local current = vim.api.nvim_get_current_buf()
    if bufnr and bufnr ~= current and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_set_current_buf(bufnr)
      local ok_linter, resolved = pcall(linter)
      vim.api.nvim_set_current_buf(current)
      if ok_linter then
        return resolved
      end
      return nil
    end

    local ok_linter, resolved = pcall(linter)
    if ok_linter then
      return resolved
    end
    return nil
  end

  return linter
end

local function get_buffer_formatter_names(bufnr)
  local ok, conform = pcall(require, "conform")
  if not ok then
    return {}
  end

  local filetype = vim.bo[bufnr].filetype
  local formatter_spec = conform.formatters_by_ft[filetype] or conform.formatters_by_ft["_"]
  if type(formatter_spec) == "function" then
    return formatter_spec(bufnr) or {}
  end

  if type(formatter_spec) == "table" then
    return formatter_spec
  end

  return {}
end

local function render_format_debug(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local normalized = vim.fs.normalize(filename)
  local filetype = vim.bo[bufnr].filetype
  local conform_ok, conform = pcall(require, "conform")
  local lint_ok, lint = pcall(require, "lint")
  local lines = {
    "# Format Debug",
    "",
    "- buffer: `" .. normalized .. "`",
    "- filetype: `" .. filetype .. "`",
  }

  if filetype == "php" then
    lines[#lines + 1] = "- wordpress template: `" .. tostring(is_wordpress_template_file(filename)) .. "`"
    lines[#lines + 1] = "- phpcs standard: `" .. (find_phpcs_standard(filename) or "not found") .. "`"
  end

  if conform_ok then
    local formatter_names = get_buffer_formatter_names(bufnr)

    lines[#lines + 1] = ""
    lines[#lines + 1] = "## Formatters"
    if #formatter_names == 0 then
      lines[#lines + 1] = "- none"
    else
      for _, name in ipairs(formatter_names) do
        local info = conform.get_formatter_info(name, bufnr)
        lines[#lines + 1] = string.format(
          "- `%s` available=%s command=`%s` cwd=`%s`",
          name,
          tostring(info.available),
          info.command or "n/a",
          info.cwd or "n/a"
        )
      end
    end
  end

  if lint_ok then
    local linter_names = lint._resolve_linter_by_ft(filetype)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "## Linters"
    if #linter_names == 0 then
      lines[#lines + 1] = "- none"
    else
      for _, name in ipairs(linter_names) do
        local linter = resolve_linter(name, bufnr)
        local cmd = linter and linter.cmd or "n/a"
        local args = linter and linter.args or {}
        local rendered_args = type(args) == "table" and table.concat(args, " ") or tostring(args)
        lines[#lines + 1] = string.format(
          "- `%s` cmd=`%s` args=`%s` stdin=%s",
          name,
          cmd,
          rendered_args,
          tostring(linter and linter.stdin or false)
        )
      end
    end
  end

  vim.cmd("botright new")
  local scratch = vim.api.nvim_get_current_buf()
  vim.bo[scratch].buftype = "nofile"
  vim.bo[scratch].bufhidden = "wipe"
  vim.bo[scratch].swapfile = false
  vim.bo[scratch].modifiable = true
  vim.bo[scratch].filetype = "markdown"
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)
  vim.bo[scratch].modifiable = false
  vim.api.nvim_buf_set_name(scratch, "format-debug")
end

local function format_php_with(formatter, success_message)
  local bufnr = vim.api.nvim_get_current_buf()
  local ok, conform = pcall(require, "conform")
  if not ok then
    vim.notify("conform.nvim is not available", vim.log.levels.ERROR)
    return
  end

  if formatter == "blade_formatter_php" and not is_wordpress_template_file(vim.api.nvim_buf_get_name(bufnr)) then
    vim.notify("Current buffer is not detected as a WordPress template", vim.log.levels.WARN)
    return
  end

  local info = conform.get_formatter_info(formatter, bufnr)
  if not info.available then
    vim.notify(string.format("Formatter `%s` is not available", formatter), vim.log.levels.WARN)
    return
  end

  conform.format({
    bufnr = bufnr,
    async = false,
    lsp_format = "never",
    formatters = { formatter },
  })

  -- Post-process: fix WordPress template patterns after formatter runs.
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if is_wordpress_template_file(filename) then
    fix_wp_template_patterns(bufnr)
  end

  if success_message then
    vim.notify(success_message)
  end
end

local function render_php_formatter_label(bufnr)
  local names = get_buffer_formatter_names(bufnr)
  if #names == 0 then
    return "none"
  end

  local labels = {
    blade_formatter_php = "blade-formatter",
    phpcbf_project = "phpcbf",
  }
  local rendered = {}

  for _, name in ipairs(names) do
    table.insert(rendered, labels[name] or name)
  end

  return table.concat(rendered, ", ")
end

local function notify_php_formatter(bufnr, source)
  if source == "save" and not vim.g.php_format_notify_on_save then
    return
  end

  if vim.bo[bufnr].filetype ~= "php" then
    return
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  local basename = vim.fs.basename(filename)
  vim.notify(string.format("%s -> %s (%s)", source, basename, render_php_formatter_label(bufnr)), vim.log.levels.INFO, {
    title = "PHP Format",
  })
end

local function format_php_auto()
  local bufnr = vim.api.nvim_get_current_buf()
  local ok, conform = pcall(require, "conform")
  if not ok then
    vim.notify("conform.nvim is not available", vim.log.levels.ERROR)
    return
  end

  local formatters = get_buffer_formatter_names(bufnr)
  if #formatters == 0 then
    vim.notify("No PHP formatter available", vim.log.levels.WARN)
    return
  end

  conform.format({
    bufnr = bufnr,
    async = false,
    lsp_format = "never",
    formatters = formatters,
  })

  -- Post-process: fix WordPress template patterns after external formatters run.
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if is_wordpress_template_file(filename) then
    fix_wp_template_patterns(bufnr)
  end

  notify_php_formatter(bufnr, "format")
end

local php_wordpress_group = vim.api.nvim_create_augroup("php-wordpress-profile", { clear = true })

if vim.fn.exists(":FormatDebug") == 0 then
  vim.api.nvim_create_user_command("FormatDebug", function(opts)
    local bufnr = opts.args ~= "" and vim.fn.bufnr(opts.args) or vim.api.nvim_get_current_buf()
    if not bufnr or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
      vim.notify("Invalid buffer for FormatDebug", vim.log.levels.ERROR)
      return
    end

    render_format_debug(bufnr)
  end, {
    desc = "Show formatter and linter debug info",
    nargs = "?",
    complete = "buffer",
  })
end

if vim.fn.exists(":PhpToolchainDebug") == 0 then
  vim.api.nvim_create_user_command("PhpToolchainDebug", function(opts)
    local bufnr = opts.args ~= "" and vim.fn.bufnr(opts.args) or vim.api.nvim_get_current_buf()
    if not bufnr or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
      vim.notify("Invalid buffer for PhpToolchainDebug", vim.log.levels.ERROR)
      return
    end

    render_format_debug(bufnr)
  end, {
    desc = "Show PHP toolchain debug info",
    nargs = "?",
    complete = "buffer",
  })
end

if vim.fn.exists(":PhpFormatBlade") == 0 then
  vim.api.nvim_create_user_command("PhpFormatBlade", function()
    format_php_with("blade_formatter_php", "Formatted with blade-formatter")
  end, {
    desc = "Format current buffer with blade-formatter only",
  })
end

if vim.fn.exists(":PhpFormatPhpcbf") == 0 then
  vim.api.nvim_create_user_command("PhpFormatPhpcbf", function()
    format_php_with("phpcbf_project", "Formatted with PHPCBF")
  end, {
    desc = "Format current buffer with PHPCBF only",
  })
end

-- Keep PHP editing sane in mixed PHP/HTML templates.
-- Tree-sitter struggles with mixed PHP/HTML in WordPress templates,
vim.api.nvim_create_autocmd("FileType", {
  group = php_wordpress_group,
  pattern = "php",
  callback = function(event)
    vim.opt_local.foldmethod = "indent"
    vim.opt_local.foldlevel = 99 -- abre todo por defecto

    -- Force tabs for WordPress template files (WPCS compliance)
    local filename = vim.api.nvim_buf_get_name(event.buf)
    if is_wordpress_template_file(filename) then
      vim.opt_local.expandtab = false  -- Use real tabs, not spaces
      vim.opt_local.shiftwidth = 4
      vim.opt_local.tabstop = 4
      vim.opt_local.softtabstop = 4
    end
  end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
  group = php_wordpress_group,
  pattern = "*.php",
  desc = "Notify active PHP formatter after save",
  callback = function(event)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(event.buf) then
        notify_php_formatter(event.buf, "save")
      end
    end)
  end,
})

-- Auto-fix WordPress template patterns after saving.
-- Runs the post-processor after conform's format_on_save and rewrites the file
-- if any patterns were fixed (collapsing multi-line control structures, fixing
-- closing-tag indentation). Uses `noautocmd write` to avoid recursive triggers.
vim.api.nvim_create_autocmd("BufWritePost", {
  group = php_wordpress_group,
  pattern = "*.php",
  desc = "Fix WordPress template patterns after save",
  callback = function(event)
    local bufnr = event.buf
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local filename = vim.api.nvim_buf_get_name(bufnr)
    if not is_wordpress_template_file(filename) then
      return
    end

    if fix_wp_template_patterns(bufnr) then
      vim.cmd("silent! noautocmd write")
    end
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
      opts.linters.phpcs = function()
        local phpcs = require("lint.linters.phpcs")
        local filename = vim.api.nvim_buf_get_name(0)
        local standard = find_phpcs_standard(filename)
        local args = { "-q", "--report=json" }

        if standard then
          table.insert(args, "--standard=" .. standard)
        end

        table.insert(args, "--stdin-path=" .. filename)
        table.insert(args, "-")

        return vim.tbl_deep_extend("force", phpcs, {
          cmd = find_project_executable(filename, "phpcs"),
          args = args,
        })
      end
    end,
  },

  -- Formatter: PHPCBF aligned with the project's composer lint:fix command.
  {
    "stevearc/conform.nvim",
    keys = {
      {
        "<leader>cD",
        function()
          vim.cmd("FormatDebug")
        end,
        desc = "Format Debug",
      },
      {
        "<leader>cI",
        function()
          vim.cmd("ConformInfo")
        end,
        desc = "Conform Info",
      },
      {
        "<leader>cf",
        function()
          if vim.bo.filetype == "php" then
            format_php_auto()
            return
          end

          require("conform").format({ force = true })
        end,
        desc = "Format",
      },
      {
        "<leader>cB",
        function()
          vim.cmd("PhpFormatBlade")
        end,
        desc = "PHP Format Blade",
      },
      {
        "<leader>cP",
        function()
          vim.cmd("PhpToolchainDebug")
        end,
        desc = "PHP Toolchain Debug",
      },
      {
        "<leader>cR",
        function()
          vim.cmd("PhpFormatPhpcbf")
        end,
        desc = "PHP Format PHPCBF",
      },
    },
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.blade = { "blade_formatter_php" }
      opts.formatters_by_ft.php = function(bufnr)
        local filename = vim.api.nvim_buf_get_name(bufnr)
        if is_wordpress_template_file(filename) then
          -- WordPress template: format HTML first, then PHPCBF enforces tabs (WPCS)
          return { "blade_formatter_php", "phpcbf_project" }
        end
        -- Pure PHP file: only PHPCBF
        return { "phpcbf_project" }
      end

      opts.formatters = opts.formatters or {}
      opts.formatters.blade_formatter_php = {
        command = function(_, ctx)
          return find_node_executable(ctx.filename, "blade-formatter")
        end,
        args = { "--stdin", "--no-php-syntax-check", "--php-version", "8.2", "--indent-size", "4", "--wrap-line-length", "120" },
        stdin = true,
        cwd = function(_, ctx)
          return resolve_search_path(ctx.filename)
        end,
        condition = function(_, ctx)
          return find_node_executable(ctx.filename, "blade-formatter") ~= nil
        end,
      }

      opts.formatters.phpcbf_project = {
        inherit = "phpcbf",
        command = function(_, ctx)
          return find_project_executable(ctx.filename, "phpcbf")
        end,
        prepend_args = function(_, ctx)
          local standard = find_phpcs_standard(ctx.filename)
          if not standard then
            return {}
          end

          return { "--standard=" .. standard }
        end,
        cwd = function(_, ctx)
          return resolve_search_path(ctx.filename)
        end,
      }
    end,
  },
}
