# Conception — jalon J1

| Fichier | Rôle |
| --- | --- |
| [`J1-dossier-conception.tex`](J1-dossier-conception.tex) | Dossier de conception, source LaTeX (figures en TikZ incluses) |
| [`J1-dossier-conception.pdf`](J1-dossier-conception.pdf) | Livrable : page de garde, sommaire et 5 pages de contenu |
| `logo-uac.jpeg`, `logo-ifri.png` | Logos de la page de garde |

Compiler le PDF (pdfLaTeX, deux passes pour le sommaire et les renvois), depuis ce dossier ou sur Overleaf :

```bash
pdflatex J1-dossier-conception.tex && pdflatex J1-dossier-conception.tex
```

Paquets nécessaires (TeX Live) : `babel-french`, `fancyhdr`, `setspace`, `enumitem`, `listings`, `hypcap`, `pgf` (TikZ), `cm-super`.
