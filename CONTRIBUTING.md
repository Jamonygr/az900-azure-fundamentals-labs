# Contributing

Use a branch and pull request. Describe the learner problem, the resulting behavior, and the checks performed.

Authoritative lessons are `labs/*/README.md`; metadata is `labs/*/lab.json`, coverage is `curriculum/blueprint.json`, and questions are `labs/*/questions.json`. Update the catalog when metadata changes. Generated `.site-docs` and `site` files are not committed.

The site landing page is authored in `HOME.md`; its marked statistics, domain cards, and lab cards are populated by `tools/build_docs.py`. The GitHub front page is `README.md`. Keep the existing lesson URLs and browser-progress format stable. Teaching SVGs need accessible titles/descriptions, descriptive lesson alt text, a caption, and a full-size link. Review rendered diagrams for accuracy and clipping; see `ASSET_NOTES.md` for artwork sources and the cover prompt.

Use original scenarios and official Microsoft references. Map each new or corrected question to a taught objective and a valid lesson anchor. Keep four plausible options, exactly one correct answer, and explanations for every choice. Avoid copied exam items, position cues, and duplicate questions.

Run the README checks, Bicep compilation, and secret scanning before submitting. Never commit credentials, live output, subscription identifiers, or learner evidence. Mock Azure in automated tests. A claim of live verification needs a documented deployment, validation, cleanup, and residual-resource audit in an approved disposable environment.
