-- papers.lua: renders papers.yml as publication entries.
--
-- Shortcodes:
--   {{< papers section="published" >}}   list of papers in a section
--   {{< papers-bib-all >}}               "download all (.bib)" link
--
-- Each entry gets: title (linked), coauthors, citation, and buttons for
-- Abstract, Ungated, Zotero (.ris download), BibTeX (with copy button),
-- plus any extra links. Papers with a `journal` also get an embedded
-- COinS span, so the Zotero browser connector can save them directly.

local utils = pandoc.utils

---------------------------------------------------------------- helpers

local function ptype(v) return utils.type(v) end

local function str(v)
  if v == nil then return nil end
  local s = utils.stringify(v)
  if s == "" then return nil end
  return s
end

local function as_inlines(v)
  local t = ptype(v)
  if t == "Inlines" then return v end
  if t == "Blocks" then return utils.blocks_to_inlines(v) end
  return pandoc.Inlines(pandoc.Str(str(v) or ""))
end

local function as_blocks(v)
  local t = ptype(v)
  if t == "Blocks" then return v end
  return pandoc.Blocks({ pandoc.Para(as_inlines(v)) })
end

local function to_latex(v)
  local doc = pandoc.Pandoc({ pandoc.Plain(as_inlines(v)) })
  return (pandoc.write(doc, "latex", { wrap_text = "none" }):gsub("%s+$", ""))
end

local function urlencode(s)
  return (s:gsub("[^%w%-_%.~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

local function html_escape(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- "Keith E. Schnakenberg" -> "Schnakenberg, Keith E."
local function last_first(name)
  local first, last = name:match("^(.-)%s+(%S+)$")
  if not last then return name end
  return last .. ", " .. first
end

local function split_pages(p)
  if not p then return nil, nil end
  local a, b = p:match("^(%d+)%s*[-–]+%s*(%d+)$")
  if a then return a, b end
  return p, nil
end

local function project_file(name)
  local dir = quarto and quarto.project and quarto.project.directory
  if dir then return pandoc.path.join({ dir, name }) end
  return name
end

local cache = nil
local function load_papers()
  if cache then return cache end
  local path = project_file("papers.yml")
  local f = io.open(path, "r")
  if not f then error("papers.lua: cannot open " .. path) end
  local txt = f:read("a"); f:close()
  cache = pandoc.read("---\n" .. txt .. "\n---\n", "markdown").meta
  return cache
end

local function authors_of(p)
  local list = {}
  for _, a in ipairs(p.authors or {}) do
    table.insert(list, {
      name = str(a.name),
      url = str(a.url),
      me = a.me == true or str(a.me) == "true",
    })
  end
  return list
end

---------------------------------------------------------------- citations

-- "article" for papers with a journal; "manuscript" for working papers that
-- have a paper link (or `cite: true`); nil means no citation buttons.
local function cite_kind(p)
  if p.cite ~= nil and (p.cite == false or str(p.cite) == "false") then return nil end
  if p.journal then return "article" end
  if p.cite == true or str(p.cite) == "true" then return "manuscript" end
  if p.type and str(p.type) == "book" then return nil end
  if str(p.url) then return "manuscript" end
  return nil
end

local function ms_year(p) return str(p.year) or os.date("%Y") end
local function ms_note(p)
  return str(p.note) or str(load_papers().manuscript_note) or "Unpublished manuscript"
end

local function bibtex(p)
  local kind = cite_kind(p)
  local names = {}
  for _, a in ipairs(authors_of(p)) do table.insert(names, last_first(a.name)) end
  local fields
  if kind == "manuscript" then
    fields = {
      { "author", table.concat(names, " and ") },
      { "title", "{" .. to_latex(p.title) .. "}" },
      { "note", ms_note(p) },
      { "year", ms_year(p) },
      { "url", str(p.url) },
    }
  else
  fields = {
    { "author", table.concat(names, " and ") },
    { "title", "{" .. to_latex(p.title) .. "}" },
    { "journal", to_latex(p.journal) },
    { "year", str(p.year) or str(p.status) },
    { "volume", str(p.volume) },
    { "number", str(p.number) },
    { "pages", str(p.pages) and str(p.pages):gsub("%s*[-–]+%s*", "--") },
    { "doi", str(p.doi) },
  }
  if not str(p.doi) and str(p.url) then table.insert(fields, { "url", str(p.url) }) end
  end
  local out = { (kind == "manuscript" and "@unpublished{" or "@article{") .. str(p.id) .. "," }
  for _, kv in ipairs(fields) do
    if kv[2] then
      table.insert(out, string.format("  %-7s = {%s},", kv[1], kv[2]))
    end
  end
  out[#out] = out[#out]:gsub(",$", "")
  table.insert(out, "}")
  return table.concat(out, "\n")
end

local function ris(p)
  local kind = cite_kind(p)
  local L = { kind == "manuscript" and "TY  - UNPB" or "TY  - JOUR" }
  local function add(tag, v) if v then table.insert(L, tag .. "  - " .. v) end end
  for _, a in ipairs(authors_of(p)) do add("AU", last_first(a.name)) end
  add("TI", str(p.title))
  add("T2", str(p.journal))
  add("PY", kind == "manuscript" and ms_year(p) or str(p.year))
  if kind == "manuscript" then add("M3", ms_note(p)) end
  add("VL", str(p.volume))
  add("IS", str(p.number))
  local sp, ep = split_pages(str(p.pages))
  add("SP", sp); add("EP", ep)
  add("DO", str(p.doi))
  add("UR", str(p.doi) and ("https://doi.org/" .. str(p.doi)) or str(p.url))
  add("AB", str(p.abstract))
  if str(p.status) and kind ~= "manuscript" then add("N1", str(p.status)) end
  table.insert(L, "ER  - ")
  return table.concat(L, "\r\n") .. "\r\n"
end

-- COinS (OpenURL) span: lets the Zotero Connector detect each paper on the page
local function coins(p)
  local kv = {
    "ctx_ver=Z39.88-2004",
    "rft_val_fmt=" .. urlencode("info:ofi/fmt:kev:mtx:journal"),
    "rft.genre=article",
    "rft.atitle=" .. urlencode(str(p.title)),
    "rft.jtitle=" .. urlencode(str(p.journal)),
  }
  local function add(k, v) if v then table.insert(kv, k .. "=" .. urlencode(v)) end end
  add("rft.date", str(p.year))
  add("rft.volume", str(p.volume))
  add("rft.issue", str(p.number))
  local sp, ep = split_pages(str(p.pages))
  add("rft.spage", sp); add("rft.epage", ep)
  for _, a in ipairs(authors_of(p)) do add("rft.au", a.name) end
  if str(p.doi) then add("rft_id", "info:doi/" .. str(p.doi))
  elseif str(p.url) then add("rft_id", str(p.url)) end
  return '<span class="Z3988" title="' .. html_escape(table.concat(kv, "&")) .. '"></span>'
end

---------------------------------------------------------------- rendering

local function meta_line(p)
  local inl = pandoc.Inlines({})
  local co = {}
  for _, a in ipairs(authors_of(p)) do
    if not a.me then
      if a.url then
        table.insert(co, pandoc.Link(a.name, a.url, "", { target = "_blank" }))
      else
        table.insert(co, pandoc.Str(a.name))
      end
    end
  end
  if #co > 0 then
    inl:insert(pandoc.Str("with "))
    for i, c in ipairs(co) do
      if i > 1 then
        inl:insert(pandoc.Str(i == #co and (#co > 2 and ", and " or " and ") or ", "))
      end
      inl:insert(c)
    end
    inl:insert(pandoc.Str(". "))
  end
  if p.journal then
    if str(p.year) then inl:insert(pandoc.Str(str(p.year) .. ". "))
    elseif str(p.status) then inl:insert(pandoc.Str(str(p.status) .. ". ")) end
    inl:insert(pandoc.Emph(as_inlines(p.journal)))
    local cite = ""
    if str(p.volume) then cite = " " .. str(p.volume) end
    if str(p.number) then cite = cite .. "(" .. str(p.number) .. ")" end
    if str(p.pages) then cite = cite .. ": " .. str(p.pages):gsub("%s*[-–]+%s*", "–") end
    inl:insert(pandoc.Str(cite .. "."))
  elseif str(p.status) then
    inl:insert(pandoc.Strong(pandoc.Emph(str(p.status))))
  end
  return inl
end

local function button_link(label, icon, href, title, extra)
  return string.format(
    '<a class="paper-btn" href="%s" title="%s"%s><i class="bi bi-%s"></i> %s</a>',
    href, html_escape(title or label), extra or ' target="_blank"', icon, label)
end

local function button_toggle(label, icon, target)
  return string.format(
    '<button type="button" class="paper-btn" data-paper-toggle="%s" aria-expanded="false"><i class="bi bi-%s"></i> %s</button>',
    target, icon, label)
end

local function render_paper(p, n)
  local id = str(p.id) or ("paper" .. n)
  local blocks = pandoc.Blocks({})

  -- title
  local title = as_inlines(p.title)
  if str(p.url) then
    title = pandoc.Inlines({ pandoc.Link(title, str(p.url), "", { target = "_blank" }) })
  end
  if p.type and str(p.type) == "book" then title = pandoc.Inlines({ pandoc.Emph(title) }) end
  blocks:insert(pandoc.Div(pandoc.Plain(title), pandoc.Attr("", { "paper-title" })))

  -- coauthors / citation
  local ml = meta_line(p)
  if #ml > 0 then blocks:insert(pandoc.Div(pandoc.Plain(ml), pandoc.Attr("", { "paper-meta" }))) end

  -- buttons
  local btns = {}
  local has_abs = p.abstract ~= nil
  if has_abs then
    table.insert(btns, button_toggle(str(p.abstract_label) or "Abstract", "card-text", id .. "-abs"))
  end
  if str(p.ungated) then
    table.insert(btns, button_link("Ungated", "unlock", str(p.ungated), "Free version"))
  end
  local kind = cite_kind(p)
  local citable = kind ~= nil
  if citable then
    table.insert(btns, string.format(
      '<button type="button" class="paper-btn" data-download="%s.ris" data-mime="application/x-research-info-systems" data-content="%s" title="Download citation (.ris) — opens in Zotero, EndNote, or Mendeley"><i class="bi bi-bookmark-plus"></i> Zotero</button>',
      id, html_escape(ris(p))))
    table.insert(btns, button_toggle("BibTeX", "braces", id .. "-bib"))
  end
  for _, l in ipairs(p.links or {}) do
    table.insert(btns, button_link(str(l.label), str(l.icon) or "link-45deg", str(l.url)))
  end
  if #btns > 0 then
    blocks:insert(pandoc.RawBlock("html", '<div class="paper-btns">' .. table.concat(btns, " ") .. "</div>"))
  end

  -- hidden panels
  if has_abs then
    blocks:insert(pandoc.Div(as_blocks(p.abstract), pandoc.Attr(id .. "-abs", { "paper-panel", "paper-abstract" })))
  end
  if citable then
    blocks:insert(pandoc.Div(
      pandoc.CodeBlock(bibtex(p), pandoc.Attr("", { "bibtex" })),
      pandoc.Attr(id .. "-bib", { "paper-panel", "paper-bibtex" })))
    if kind == "article" then blocks:insert(pandoc.RawBlock("html", coins(p))) end
  end

  return pandoc.Div(blocks, pandoc.Attr("", { "paper" }))
end

---------------------------------------------------------------- shortcodes

return {
  ["papers"] = function(args, kwargs)
    if not quarto.doc.is_format("html") then return pandoc.Null() end
    local section = str(kwargs["section"]) or "published"
    local papers = load_papers()[section] or {}
    local out = pandoc.Blocks({})
    for i, p in ipairs(papers) do out:insert(render_paper(p, section .. i)) end
    return out
  end,

  ["papers-bib-all"] = function(args, kwargs)
    local all = {}
    for _, sec in ipairs({ "published", "working" }) do
      for _, p in ipairs(load_papers()[sec] or {}) do
        if cite_kind(p) then table.insert(all, bibtex(p)) end
      end
    end
    return pandoc.RawInline("html",
      '<button type="button" class="paper-btn" data-download="turner-papers.bib" data-mime="application/x-bibtex" data-content="' ..
      html_escape(table.concat(all, "\n\n") .. "\n") ..
      '"><i class="bi bi-download"></i> All papers (.bib)</button>')
  end,
}
