local Path = require("plenary.path")

--- Checks to see if the default or passed in patterns for a root file are
--- found or not for the given target level.
local has_pattern = function(patterns, target)
  for _, pattern in ipairs(patterns) do
    local what_we_are_looking_for = Path:new(target, pattern)
    if what_we_are_looking_for:exists() then
      return pattern
    end
  end
end

--- NOTE: maxParentSearch lets you check up to a certain number of parent
--- folders to find nested build files.
--- Given a situation like the below one where you have a root build.sbt
--- and one in your module a, you want to ensure the root is correctly set as
--- the root one, not the a one. This checks the parent dir to ensure this.
--- build.sbt  <-- this is the root
--- a/
---  - build.sbt <- this is not
---  - src/main/scala/Main.scala
--- If your projects are multiple layers deep, set
--- config.find_root_dir_max_project_nesting to a greater number. Default is 1
--- for the behavior described above.
local find_root_dir = function(patterns, startpath, maxParentSearch)
  local path = Path:new(startpath)
  -- First parent index in which we found a target file
  local firstFoundIdx = nil
  local ret = nil
  local found = nil

  for i, parent in ipairs(path:parents()) do
    -- Exit loop before checking anything if we've exceeded the search limits
    if (firstFoundIdx and (i - firstFoundIdx > maxParentSearch)) or parent == "/" then
      return ret
    end

    local pattern = has_pattern(patterns, parent)

    -- We add an extra guard here that if there is a pattern and we've already found one
    -- we make sure it's the same as the found one. For example we don't want to detect a
    -- .scala-build nested and then look one deeper and see a .git and incorrectly mark .git
    -- as the root.
    if (pattern and not found) or (pattern and found == pattern) then
      -- Mark the first parent that was found, so we can exit the loop when we've exhausted our search limits
      if not firstFoundIdx then
        found = pattern
        firstFoundIdx = i
      end
      -- (over)write the return value with the highest parent found
      ret = parent
    end
  end
  -- In case we went through the entire loop (e.g. if maxParentSearch is really high)
  return ret
end

return {
  find_root_dir = find_root_dir,
}
