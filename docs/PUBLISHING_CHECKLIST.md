# Publishing status and remaining evidence

## Prepared in this package

- README with a clear business question and financial findings.
- Fictional Alov Bank profile.
- Financial and risk analysis, including limitations and metric definitions.
- SQL upgrade, analysis queries and read-only checks.
- Data dictionary and entity relationships.
- Reproducible seed analysis and expanded-history generator.
- Three report visuals and recorded test evidence.
- Setup guide, data provenance, roadmap and .gitignore.

## Decisions and evidence still needed

1. The fictional project name is **Alov Bank**. The name implies no affiliation with a real bank.
2. Restore the expanded demo and confirm the small V2 script ran successfully. Add screenshots of the database, health checks, a transaction/reversal, the trial balance and one financial result. Remove passwords and connection details from screenshots.
3. Choose a license for the code and terms for the synthetic data. No license has been silently selected in this package. A public repository does not automatically grant a general open-source license; see [GitHub's licensing guide](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).
4. The snapshot and expanded synthetic archives are published under [data/](../data/README.md). The expanded archive uses 14 verified parts and an automatic downloader. The historical lending SQL is generated locally with `historical_2025/build.py`.
5. The repository is published with README.md at its root, three charts, scripts, reports and synthetic database downloads.
6. Add the repository URL to your CV only once you have reviewed the SQL and can explain the findings, limitations and AI-assisted development process.

GitHub's browser file upload limit is 25 MiB; regular Git warns above 50 MiB and blocks files above 100 MiB. Large release assets have separate limits. See the [official file-size guidance](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github).

## Suggested repository metadata

Description: Synthetic banking portfolio combining MySQL transaction controls, double-entry accounting and financial risk analysis.

Topics: mysql, sql, banking, financial-analysis, data-analysis, portfolio, synthetic-data, accounting.

Suggested screenshots: financial summary; product concentration; successful health check; failed insufficient-funds operation; successful reversal; second-user approval. These are requested evidence, not fabricated screenshots or completed checks.
