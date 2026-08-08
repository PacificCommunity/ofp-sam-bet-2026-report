-- Keep each report figure and Pandoc table on its own printed page.
-- Raw LaTeX longtables are separated explicitly in Assessment-tables.qmd.
local function page_break()
  return pandoc.RawBlock('latex', '\\clearpage')
end

function Figure(el)
  return {page_break(), el, page_break()}
end

function Para(el)
  if #el.content == 1 and el.content[1].t == 'Image' then
    return {page_break(), el, page_break()}
  end
  return nil
end

function Table(el)
  return {page_break(), el, page_break()}
end
