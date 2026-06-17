local Sections = {}
Sections.__index = Sections

function Sections.new(view_name)
  return setmetatable({ view_name = view_name, collapsed = {}, _keys = {}, _expand_all = false }, Sections)
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
  if self._expand_all then return false end
  return self.collapsed[key] ~= false
end

function Sections:collapse_all()
  self._expand_all = false
  for key, _ in pairs(self._keys) do
    self.collapsed[key] = true
  end
end

function Sections:expand_all()
  self._expand_all = false
  for key, _ in pairs(self._keys) do
    self.collapsed[key] = false
  end
end

return Sections
