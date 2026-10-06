# Brazil's Capital Has a 28x Education Gap Among Its Voters

An original SQL and Tableau project using official open data from Brazil's Electoral Court (TSE) to find out who the voters of the Federal District (Distrito Federal, DF) are and where they live, down to each polling station.

**Tools:** SQLite, DBeaver, Tableau Public

📊 **Interactive dashboard (in Portuguese):** [Escolaridade dos Eleitores do DF on Tableau Public](https://public.tableau.com/views/BrazilFederalDistrictVoters2026/EscolaridadedosEleitoresdoDF)

## Goal

Before the 2026 election, I wanted to understand the electorate of Brazil's capital: education, age, gender and disability, and how they change from one neighbourhood to another. I also wanted to check whether polling stations are accessible to the voters who need it.

## Data

Two files from the [TSE Open Data Portal](https://dadosabertos.tse.jus.br/):

- `perfil_eleitor_secao_2026_DF`: voter profile by polling section (2,253,132 voters, 7,042 sections). Generated on 14/07/2026, which is the final electorate for the 4 October 2026 election.
- `eleitorado_local_votacao_2026`: polling places, with neighbourhood, latitude and longitude, and accessibility.

The raw files are too big for GitHub (over 100 MB), so they are not in this repo. You can download them from the link above.

## Files

| File | What it does |
|---|---|
| `analise_df.sql` | All my queries, from exploration to the final view for Tableau (comments in Portuguese) |
| `secoes_para_tableau.csv` | The final view exported for Tableau, one row per section (7,042 rows) |

## What I did

1. **Exploration:** totals, gender, education, age groups and a data quality check on race.
2. **Cleaning:** I looked for strange values (7 voters with an invalid age, 5 with no gender). I kept them, so the total still matches the official TSE number, and filtered them out only in the age analysis. I also found sections with very few voters that distort percentages, and flagged sections under 50 voters.
3. **One row per section:** I built a view with the profile of each section (education, optional voters, illiteracy, disability, school name).
4. **Advanced analysis:** zone ranking with `RANK()` and weighted averages, education quartiles with `NTILE(4)` in a CTE, and a `LEFT JOIN` with the polling places file to add neighbourhood, map location and accessibility.
5. **Fixing neighbourhood names:** in the TSE file, the neighbourhoods of Gama are only called "SETOR LESTE", "SETOR SUL" and so on, and Brazlândia has neighbourhoods with the same names. I added the city name in brackets so the two cities don't get mixed up.
6. **Tableau dashboard:** KPIs, a map of the polling schools, neighbourhood rankings and accessibility by education level.

## Key findings

- **The education gap is huge.** 23.3% of DF voters have a university degree. By neighbourhood, it goes from 70.7% in Setor Sudoeste to 2.5% in Cidade Estrutural, a 28x gap. By electoral zone, it goes from 58% (zone 1, Plano Piloto) to 7% (zone 21, Recanto das Emas).
- **Optional voters live in opposite parts of the DF.** The most educated sections have 2.4 times more voters aged 70+ (13.2% against 5.4%), and the least educated sections have 14 times more illiterate voters (1.4% against 0.1%).
- **Accessibility is worse where you might expect it to be better.** 608 sections have no accessibility, and about 1,800 voters with a disability are registered in them. In the most educated quartile, 16.2% of sections have no accessibility, against 6.3% in the least educated quartile.
- **Missing data is a finding too.** 83% of voters have no race recorded, so I couldn't use race in the analysis.

## Skills

CTEs, window functions (`RANK`, `NTILE`), weighted averages, `CASE WHEN`, `LEFT JOIN`, subqueries, views, `HAVING`, data quality checks, Tableau maps, parameters and filter actions.

## Limitations

- This is a profile of registered voters, not of the whole population.
- Race can't be analysed because 83% of the values are missing.
- Sections with very few voters give extreme percentages, so I filtered sections under 50 voters in the section-level charts.
