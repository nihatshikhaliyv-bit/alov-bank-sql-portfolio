# Before publishing on GitHub

## Prepared in this package

- README with a clear business question and financial findings.
- Fictional-bank profile with the name left open.
- Financial and risk analysis, including limitations and metric definitions.
- SQL upgrade, analysis queries and read-only checks.
- Data dictionary and entity relationships.
- Reproducible seed analysis and expanded-history generator.
- Three report visuals and recorded test evidence.
- Setup guide, data provenance, roadmap and .gitignore.

## Decisions and evidence still needed

1. Replace the literal `BANK_NAME` throughout the Markdown files with your chosen name. Check that the title does not imply affiliation with an actual bank.
2. Restore the expanded demo and confirm the small V2 script ran successfully. Add screenshots of the database, health checks, a transaction/reversal, the trial balance and one financial result. Remove passwords and connection details from screenshots.
3. Choose a license for the code and terms for the synthetic data. No license has been silently selected in this package. A public repository does not automatically grant a general open-source license; see [GitHub's licensing guide](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository).
4. Put the large expanded `.sql.gz` in a GitHub Release or another suitable download location, not in regular Git history. Link it from data/README.md after the release exists. No download URL is invented here.
5. Extract the repository ZIP and upload its CONTENTS so README.md is at the repository root. The small seed dump is compressed; the expanded dump stays outside this folder.
6. Add the repository URL to your CV only once you have reviewed the SQL and can explain the findings, limitations and AI-assisted development process.

GitHub's browser file upload limit is 25 MiB; regular Git warns above 50 MiB and blocks files above 100 MiB. Large release assets have separate limits. See the [official file-size guidance](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github).

## Suggested repository metadata

Description: Synthetic banking portfolio combining MySQL transaction controls, double-entry accounting and financial risk analysis.

Topics: mysql, sql, banking, financial-analysis, data-analysis, portfolio, synthetic-data, accounting.

Suggested screenshots: financial summary; product concentration; successful health check; failed insufficient-funds operation; successful reversal; second-user approval. These are requested evidence, not fabricated screenshots or completed checks.
