# ianrturner.com — Quarto version

## Preview locally
Open this folder in RStudio (File → Open Project in New Session, or just open
`index.qmd`) and click **Render**, or in a terminal here:

    quarto preview

## Adding or editing a paper
Edit `papers.yml` only. Copy an existing entry and change the fields. A paper
with a `journal` automatically gets **Zotero** (.ris download) and **BibTeX**
buttons; `ungated` adds the Ungated button; `abstract` adds the Abstract toggle.
List authors in citation order and mark yourself with `me: true`.

## Adding a new paper — step by step

1. Open `papers.yml`. Copy the template below that fits and paste it where the
   paper should appear (order in the file = order on the page).
2. Fill it in. Keep the two-space indentation exactly as shown.
3. Render and check: in the Terminal tab run `quarto render`, then open
   `docs\research.html` (`explorer.exe "docs\research.html"`). Click the
   paper's Abstract, BibTeX and Zotero buttons once.
4. Publish (once the site is live from this folder): `git add -A`,
   `git commit -m "add paper"`, `git push`.

### Template: published article
```yaml
- id: lastname2027keyword          # BibTeX key; must be unique
  title: "Paper Title: With a Subtitle"
  authors:                          # alphabetical, as on the paper
  - name: Coauthor Name
    url: https://coauthor-website.com   # optional
  - name: Ian R. Turner
    me: true
  year: '2027'
  journal: Journal of Politics
  volume: '89'
  number: '2'
  pages: 100-120
  doi: 10.1086/123456
  url: https://publisher-page-for-the-article
  ungated: https://osf.io/preprints/socarxiv/xxxxx
  abstract: >-
    Abstract text here. It can run over several lines, as long as every
    line is indented the same amount. *Italics* and $math$ work.
```

### Template: forthcoming article
Same as above, but replace `year`, `volume`, `number`, `pages`, `doi` with:
```yaml
  status: Forthcoming
```

### Template: working paper (goes under `working:`)
```yaml
- id: lastnamewpkeyword
  title: "Working Paper Title"
  authors:
  - name: Coauthor Name
  - name: Ian R. Turner
    me: true
  status: R&R                      # optional; shown on the page
  url: https://osf.io/preprints/socarxiv/xxxxx   # gives it Zotero/BibTeX buttons
  abstract: >-
    Abstract text here.
```

### When a working paper is accepted
Move its entry from `working:` up to `published:`, delete `status: R&R`, and
add `journal:` plus either `status: Forthcoming` or the year/volume/pages/doi.
Put the OSF link in `ungated:` and the publisher link in `url:`.

### Common mistakes (the render will fail or the entry will look wrong)
- **Colons in titles:** wrap the title in quotes, e.g. `title: "Signaling: A Model"`.
- **Indentation:** use spaces, not tabs; line things up with the entry above.
- **Numbers:** quote years/volumes (`'2027'`) so they aren't read as numbers.
- **Duplicate `id`:** each paper needs its own.
- If something breaks, the error message names the line in `papers.yml`.

## Files
- `index.qmd` — home page (photo, bio, links)
- `research.qmd` — Research page (pulls from `papers.yml`)
- `teaching.qmd` — Teaching page
- `_quarto.yml` — site settings and navigation bar
- `styles.scss` — colors/fonts (Pitt blue and gold)
- `_extensions/papers/` — code that turns `papers.yml` into the entries

## Publishing (when ready to replace the current site)
The site builds into `docs/`. Copy this project into the
`irturner.github.io` repo, run `quarto render`, commit, and push. Then on
GitHub: repo → Settings → Pages → "Deploy from a branch" → `master` / `/docs`.
`CNAME` is copied automatically, so www.ianrturner.com keeps working.
