# Contributing

Thanks for considering a contribution.

Before changing code, read:

- [`README.md`](README.md)
- [`implementation_for_agents.md`](implementation_for_agents.md)
- [`context.md`](context.md)

Project rules:

- Keep public documentation in English.
- Do not create tests in this repository.
- Do not add runtime third-party dependencies without explicit approval.
- Keep the package iOS-only unless platform support is implemented and validated.
- Check Apple Foundation Models availability before invoking model requests.
- Keep offline behavior as `ModelMode.local` plus `CloudPolicy.never`.
- Do not silently route requests to Private Cloud Compute.
- Update `context.md` when architecture, behavior, or operational workflows change.

Validation:

```bash
/Users/villa/Developer/tools/flutter/bin/flutter analyze
cd example && /Users/villa/Developer/tools/flutter/bin/flutter analyze
/Users/villa/Developer/tools/flutter/bin/dart pub publish --dry-run
```
