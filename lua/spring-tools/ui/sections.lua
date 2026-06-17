local Sections = {}
Sections.__index = Sections

function Sections.new(view_name)
  return setmetatable({ view_name = view_name, collapsed = {}, _keys = {} }, Sections)
end

function Sections:toggle(key)
  self._keys[key] = true
  if self.collapsed[key] == false then
    self.collapsed[key] = true
  else
    self.collapsed[key] = false
  end
end

function Sections:is_collapsed(key)
  self._keys[key] = true
  return self.collapsed[key] ~= false
end

function Sections:collapse_all()
  for key, _ in pairs(self._keys) do
    self.collapsed[key] = true
  end
end

function Sections:expand_all()
  for key, _ in pairs(self._keys) do
    self.collapsed[key] = false
  end
end

return Sections
