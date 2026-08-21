# Commit Guidelines

Use concise commit messages that describe the framework area changed.

Recommended format:

```text
<type>: <summary>
```

Examples:

```text
feat: add options loading and default logger
refactor: separate HTTP components from dependency registrations
docs: document container and routing conventions
fix: validate middleware contract during route scanning
```

Common types:

- `feat`: new feature;
- `fix`: bug fix;
- `refactor`: internal restructuring without behavior change;
- `docs`: documentation only;
- `test`: tests;
- `chore`: project maintenance.

For the current options/logger work, a suitable message is:

```text
feat: add typed options loading and default logger
```
