# Internship Final Report

LaTeX framework for the Professional Thesis report. The structure follows
`230614_FOR_DNM Professional Thesis Report Instructions.pdf`, supplied separately and
intentionally not copied into the repository.

Two files only, so the project drops straight into Overleaf:

| File | Purpose |
| --- | --- |
| `main.tex` | The whole document: preamble, cover, front matter, three sections, appendices |
| `references.bib` | Bibliography entries, including sources for non-original figures |

Put any images in a `figures/` folder inside the project; `main.tex` sets `\graphicspath` to it.

Later Overleaf handoff: upload only `main.tex` and `references.bib`; add `figures/` only when
report images are introduced. `main.tex` is the canonical source.

## Requirements captured from the instructions

- Length: 40 pages ±5, **excluding appendices**, including all text, figures, tables, and
  diagrams. The instructions do not say whether front matter counts — confirm with the
  internship supervisor.
- Section 1, context and institutional expectations: **maximum 5 pages**. Must not be filler,
  plagiarised company documents, or reproduced website text.
- Section 3, skills development and professional future: **maximum 5 pages**.
- Section 1 must include a personal opinion on the company's SDRS policy.
- Section 2 breaks the assignment into sub-projects, each following diagnose → solve →
  operationalize → evaluate, and must state degree of autonomy, level of responsibility, and
  contribution to decision-making.
- Section 3 uses the IMT Nord Europe engineering skills toolkit for the skills assessment.
- Required front matter: cover (student name, graduating class, company name, thesis type,
  title or subject overview), acknowledgements, detailed numbered contents, lists of figures
  and tables, English/French keyword glossary, overall project schedule (a Gantt chart is
  acceptable).
- Required back matter: conclusion, technical glossary where needed, information sources, and
  numbered appendices.
- Illustrations: figures and tables numbered separately in ascending Arabic order. **Figure
  captions go below the figure; table captions go above the table.** Every illustration must be
  commented on and referenced in the text before it appears, and must cite its source if it is
  not your own — failure to do so counts as plagiarism.

## Submission

- The PDF is due on MyLearningSpace **at least 10 days before the viva**.
- The host company must read the report carefully before it is distributed, so it can check for
  sensitive information.
- If the report is classed as confidential: mark it clearly on the report, set
  `\reportconfidentialtrue` in `main.tex`, and **do not submit it to MyLearningSpace** — send it
  to `dp-stages@imt-nord-europe.fr` and to the internship supervisor instead.

## Open points to confirm

- **Layout.** Erasmus+ does not prescribe a universal final-report font, margin, or spacing
  standard; its official guidance allows format adaptation and directs students to their higher
  education institution. The IMT instructions therefore remain authoritative. Presentation
  settings in `main.tex` are provisional until they are checked against the separate document
  derived from experimental standard Z41 006, available through IMT My Services.
- **English authorization.** The draft language is fixed to English. The supplied instructions do
  not explicitly authorize or prohibit English for a mainland-France placement, so confirm that
  choice with the school or internship supervisor before final submission.

Official Erasmus+ reference: [Learning Agreement guidance for
traineeships](https://erasmus-plus.ec.europa.eu/resources-and-tools/mobility-and-learning-agreements/learning-agreements).

## Resolved scope choices

- **Terminology appendix.** Retained because the report is written in a foreign language.
- **Intercultural section.** Removed because the placement is in mainland France; the supplied
  instructions require that analysis only for an overseas placement.

## Writing an illustration

```tex
As shown in Figure~\ref{fig:example}, the measured result ...

\begin{figure}[tbp]
  \centering
  \includegraphics[width=0.85\textwidth]{example.pdf}
  \caption{Descriptive title, with a source citation when not original~\cite{source-key}.}
  \label{fig:example}
\end{figure}
```

For tables, write `\caption` *before* the tabular so it renders above. The `caption` package
settings in `main.tex` control spacing only — they do not move a caption.

## Building

Overleaf compiles this with no configuration. To build locally, install a TeX distribution
(`texlive-latex-recommended`, `texlive-latex-extra`, `texlive-fonts-recommended`,
`texlive-lang-french`, `latexmk`), then run from this directory:

```bash
latexmk -pdf -outdir=build main.tex
```

`build/` is already gitignored, so generated artifacts stay untracked.

## Editing boundaries

- Replace every `TODO` prompt with evidence from the internship; do not fabricate company or
  project facts.
- Keep simulator evidence, real-hardware evidence, and work that remains unrun clearly separated.
- Keep detailed calculations, raw logs, and supporting material in numbered appendices when they
  are not essential to the main argument.
