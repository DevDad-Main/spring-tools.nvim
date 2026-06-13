local Sections = {}
Sections.__index = Sections

function Sections.new(view_name)
  return setmetatable({ view_name = view_name, collapsed = {} }, Sections)
end

function Sections:toggle(key)
  if self.collapsed[key] == false then
    self.collapsed[key] = true
  else
    self.collapsed[key] = false
  end
end

function Sections:is_collapsed(key)
  return self.collapsed[key] ~= false
end

return Sections
