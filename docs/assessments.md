# Practice assessments

The repository includes **600 original questions**: 30 each in Labs 01–20. Every item has four choices, one correct answer, explanations for all choices, an objective ID, sources, and a remediation anchor.

On the learning site, select a lab in the [interactive assessment](quiz.md). Answer all questions, then submit for a score and detailed feedback. Answers are visible in the source JSON, so the assessment is a study tool. Scores and progress are stored only in your browser; no account, cloud database, analytics, or telemetry is used.

For terminal practice, run:

```powershell
python tools/quiz.py --lab 01
python tools/quiz.py --lab 09 --shuffle --seed 900
```

The runner shows feedback and remediation after each answer. Use `--limit 10` for a short review. Full lab practice remains 30 questions. A lab score measures these items only and does not predict a Microsoft exam result.

Read the sources when a rule depends on service details. Official learning material and the exam can change; report outdated questions through an issue with the question ID and a current primary source.
