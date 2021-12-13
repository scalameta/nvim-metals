-- NOTE: that we don't include the command here, but instead wait
-- to construct that inside of telescope/_extensions/metals.lua.
-- The main reason is that we don't want to require("metals") in here
-- since we also want to require this table in setup as well to re-use
-- the ids to create commands there as well. So to avoid a cyclical dependency
-- issue we wait.
-- Also NOTE that these are not client commands in the LSP sense, but rather
-- just editor commands mapped to functions that a user can trigger.
local commands_table = {
  {
    id = "analyze_stacktrace",
    label = "Analyze Stacktrace",
    hint = "Analyze stacktrace from clipboard.",
  },
  {
    id = "compile_cancel",
    label = "Cancel Compilation",
    hint = "Cancel the ongoing compilation.",
  },
  {
    id = "compile_cascade",
    label = "Compile Cascade",
    hint = "Trigger a cascade compile.",
  },
  {
    id = "compile_clean",
    label = "Compile Clean",
    hint = "Trigger a clean compile.",
  },
  {
    id = "connect_build",
    label = "Connect Build",
    hint = "Connect to the current build server.",
  },
  {
    id = "copy_worksheet_output",
    label = "Copy Worksheet Output",
    hint = "Copy the evaluated worksheet output to your clipboard.",
  },
  {
    id = "disconnect_build",
    label = "Disconnect Build",
    hint = "Disconnect from the current build server.",
  },
  {
    id = "find_in_dependency_jars",
    label = "Find in Dependency Jars",
    hint = "Search config files in dependency jars.",
  },
  {
    id = "generate_bsp_config",
    label = "Generate BSP Config",
    hint = "Generate the BSP config for your build tool.",
  },
  {
    id = "goto_super_method",
    label = "Goto Super Method",
    hint = "Goto the super method of this symbol.",
  },
  {
    id = "import_build",
    label = "Import Build",
    hint = "Import the current build.",
  },
  {
    id = "install",
    label = "Install Metals",
    hint = "Install Metals.",
  },
  {
    id = "info",
    label = "Info",
    hint = "Open Metals info window.",
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
    id = "restart_build",
    label = "Restart Build",
    hint = "Restart the current build server.",
  },
  {
    id = "restart_server",
    label = "Restart Server",
    hint = "Restart Metals",
  },
  {
    id = "run_doctor",
    label = "Run Doctor",
    hint = "Run doctor.",
  },
  {
    id = "scan_sources",
    label = "Scan Sources",
    hint = "Scan all workspace sources.",
  },
  {
    id = "show_cfr",
    label = "Show decompiled with cfr",
    hint = "Show file decompiled with cfr.",
  },
  {
    id = "show_javap",
    label = "Show decompiled",
    hint = "Show file decompiled with javap.",
  },
  {
    id = "show_javap_verbose",
    label = "Show verbose decompiled",
    hint = "Show file verbosely decompiled with javap.",
  },
  {
    id = "show_semanticdb_compact",
    label = "Show compact semanticdb",
    hint = "Show compact Semanticdb from current file.",
  },
  {
    id = "show_semanticdb_detailed",
    label = "Show detailed semanticdb",
    hint = "Show detailed Semanticdb from current file.",
  },
  {
    id = "show_semanticdb_proto",
    label = "Show proto semanticdb",
    hint = "Show proto Semanticdb from current file.",
  },
  {
    id = "show_tasty",
    label = "Show TASTy",
    hint = "Show the TASTy representation of a file.",
  },
  {
    id = "start_ammonite",
    label = "Start Ammonite",
    hint = "Start the Ammonite build server.",
  },
  {
    id = "start_server",
    label = "Start Server",
    hint = "Start Metals (only useful if you have it disabled by default).",
  },
  {
    id = "stop_ammonite",
    label = "Stop Ammonite",
    hint = "Stop the Ammonite build server.",
  },
  {
    id = "super_method_hierarchy",
    label = "Super Method Hierarchy",
    hint = "Calculate inheritance hierarchy.",
  },
  {
    id = "switch_bsp",
    label = "Switch Build Server",
    hint = "Switch to another available build server.",
  },
  {
    id = "toggle_logs",
    label = "Toggle Logs",
    hint = "Toggle Metals logs.",
  },
  {
    id = "update",
    label = "Update Metals",
    hint = "Update to the latest Metals.",
  },
}

return {
  commands_table = commands_table,
}
