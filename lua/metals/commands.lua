-- NOTE that we don't include the command here, but instead wait
-- to construct that inside of telescope/_extensions/metals.lua.
-- The main reason is that we don't want to require("metals") in here
-- since we also want to require this table in setup as well to re-use
-- the ids to create commands there as well. So to avoid a cyclical dependency
-- issue we wait.
local commands_table = {
  {
    id = "ammonite_start",
    label = "Ammonite Start",
    hint = "Start the Ammonite build server.",
  },
  {
    id = "ammonite_stop",
    label = "Ammonite Stop",
    hint = "Stop the Ammonite build server.",
  },
  {
    id = "bsp_switch",
    label = "Switch Build Server",
    hint = "Switch to another available build server.",
  },
  {
    id = "build_connect",
    label = "Build Connect",
    hint = "Connect to the current build server.",
  },
  {
    id = "build_disconnect",
    label = "Build Disconnect",
    hint = "Disconnect from the current build server.",
  },
  {
    id = "build_import",
    label = "Import Build",
    hint = "Import the current build.",
  },
  {
    id = "build_restart",
    label = "Build Restart",
    hint = "Restart the current build server.",
  },
  {
    id = "compile_cancel",
    label = "Cancel Compilation",
    hint = "Cancel the ongoing compilation.",
  },
  {
    id = "compile_cascade",
    label = "Cascade Compile",
    hint = "Trigger a cascade compile.",
  },
  {
    id = "compile_clean",
    label = "Clean Compile",
    hint = "Trigger a clean compile.",
  },
  {
    id = "copy_worksheet_output",
    label = "Copy Worksheet Output",
    hint = "Copy the evauluated worksheet output to your clipboard.",
  },
  {
    id = "doctor_run",
    label = "Run Doctor",
    hint = "Run doctor.",
  },
  {
    id = "generate_bsp_config",
    label = "Generate BSP Config",
    hint = "Generate the BSP config for your build tool.",
  },
  {
    id = "info",
    label = "Info",
    hint = "Open Metals info window.",
  },
  {
    id = "install",
    label = "Install Metals",
    hint = "Install Metals.",
  },
  {
    id = "update",
    label = "Update Metals",
    hint = "Update to the latest Metals.",
  },
  {
    id = "logs_toggle",
    label = "Toggle Logs",
    hint = "Toggle Metals logs.",
  },
  {
    id = "new_scala_file",
    label = "New Scala File",
    hint = "Create a new Scala file.",
  },
  {
    id = "new_scala_project",
    label = "New Scala Project",
    hint = "Create a new Scala project.",
  },
  {
    id = "organize_imports",
    label = "Organize Imports",
    hint = "Organize your imports.",
  },
  {
    id = "quick_worksheet",
    label = "Quick Worksheet",
    hint = "Create a quick worksheet in your current working directory.",
  },
  {
    id = "reset_choice",
    label = "Reset Choice",
    hint = "Reset a specific choice.",
  },
  {
    id = "restart_server",
    label = "Restart Server",
    hint = "Restart Metals",
  },
  {
    id = "sources_scan",
    label = "Sources Scan",
    hint = "Scan all workspace sources.",
  },
  {
    id = "start_server",
    label = "Start Server",
    hint = "Start Metals (only useful if you have it disabled by default).",
  },
}

return {
  commands_table = commands_table,
}
