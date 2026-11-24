-- Debug Adapter Protocol (nvim-dap + nvim-dap-ui)
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        opts = {},
      },
    },
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      {
        "<leader>dB",
        function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end,
        desc = "Conditional Breakpoint",
      },
      {
        "<leader>dl",
        function() require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: ")) end,
        desc = "Logpoint",
      },
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue / Attach" },
      { "<leader>dn", function() require("dap").step_over() end, desc = "Step Over" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
      { "<leader>do", function() require("dap").step_out() end, desc = "Step Out" },
      { "<leader>dp", function() require("dap").pause() end, desc = "Pause" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate / Detach" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
      {
        "<leader>de",
        function() require("dapui").eval() end,
        mode = { "n", "v" },
        desc = "Evaluate Expression",
      },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- Auto-open / auto-close the UI with debug sessions
      dap.listeners.before.attach.dapui_config = function() dapui.open() end
      dap.listeners.before.launch.dapui_config = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
      dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

      -- Gutter signs (fits signcolumn = "yes:1")
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
      vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
      vim.fn.sign_define("DapLogPoint", { text = "◉", texthl = "DiagnosticInfo" })
      vim.fn.sign_define("DapStopped", { text = "→", texthl = "DiagnosticOk", linehl = "Visual" })

      -- js-debug server from pkgs.vscode-js-debug (nvim-programs.nix)
      dap.adapters["pwa-node"] = {
        type = "server",
        host = "127.0.0.1",
        port = "${port}",
        executable = {
          command = "js-debug",
          args = { "${port}", "127.0.0.1" },
        },
      }

      -- Alias VS Code's "node" type to "pwa-node" (so .vscode/launch.json works too)
      dap.adapters["node"] = function(cb, config)
        if config.type == "node" then
          config.type = "pwa-node"
        end
        local adapter = dap.adapters["pwa-node"]
        if type(adapter) == "function" then
          adapter(cb, config)
        else
          cb(adapter)
        end
      end

      -- Read the running native dev instance's inspector port automatically
      local function meetovo_debugger_port()
        local out = vim.fn.system({ "dev", "port", "debugger" })
        if vim.v.shell_error == 0 then
          local port = tonumber(vim.trim(out))
          if port then
            return port
          end
        end
        return tonumber(vim.fn.input("Debugger port: ", "9229"))
      end

      local js_configs = {
        {
          name = "Attach to Meetovo dev instance (dev port debugger)",
          type = "pwa-node",
          request = "attach",
          address = "127.0.0.1",
          port = meetovo_debugger_port,
          cwd = "${workspaceFolder}",
          sourceMaps = true,
          outFiles = { "${workspaceFolder}/backend/dist/**/*.js" },
          resolveSourceMapLocations = { "${workspaceFolder}/**", "!**/node_modules/**" },
          skipFiles = { "<node_internals>/**" },
          restart = true,
        },
        {
          name = "Attach to Node port (manual)",
          type = "pwa-node",
          request = "attach",
          address = "127.0.0.1",
          port = function() return tonumber(vim.fn.input("Port: ", "9229")) end,
          cwd = "${workspaceFolder}",
          sourceMaps = true,
          skipFiles = { "<node_internals>/**" },
        },
        {
          name = "Debug current Jest spec (Meetovo backend)",
          type = "pwa-node",
          request = "launch",
          cwd = "${workspaceFolder}/backend",
          program = "${workspaceFolder}/backend/node_modules/jest/bin/jest.js",
          args = { "${file}", "--runInBand", "--coverage=false" },
          env = { TZ = "UTC" },
          console = "integratedTerminal",
          sourceMaps = true,
          skipFiles = { "<node_internals>/**" },
        },
      }

      for _, lang in ipairs({ "typescript", "javascript" }) do
        dap.configurations[lang] = js_configs
      end
    end,
  },
}
