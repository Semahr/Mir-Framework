# Commit Organization and Message Guidelines

## 1. Fundamental principle: atomic commits

Each commit should represent a **logical unit of change** with a clearly defined, verifiable purpose.

As far as practical, each commit should provide:

- **Cohesion:** all changes contribute to the same objective.
- **Independence:** it excludes changes unrelated to its purpose.
- **Reversibility:** it can be reverted without removing unrelated functionality.
- **Traceability:** it makes clear what changed and why.
- **Consistency:** it leaves the project in a valid, buildable, verifiable state.

Do not combine all work from a day into one commit when it serves different objectives. Conversely, do not artificially split changes that form one logical operation.

## 2. Criteria for separating changes

### 2.1. Separate by responsibility

Split changes that address independent problems or needs. Examples include:

- Implementing a new feature.
- Fixing an existing bug.
- Refactoring without changing behavior.
- Updating dependencies.
- Making independent infrastructure or configuration changes.
- Updating documentation unrelated to other changes.

**Rule:** if two changes have independent reasons to exist, they should normally belong in separate commits.

### 2.2. Group by functional relationship

Group directly related changes in the same commit, even when they affect multiple files or application layers. For example, implementing an endpoint may require:

- Creating a use case.
- Changing an interface.
- Implementing a repository.
- Adding validation.
- Adding automated tests.
- Updating the endpoint documentation.

These changes may belong in one commit if they are all necessary to deliver the same functionality.

**Rule:** do not split changes solely because they belong to different files, classes, or architectural layers.

### 2.3. Separate by impact

Identify changes that affect behavior, contracts, or critical components. Pay particular attention to:

- Breaking changes to public APIs or interfaces.
- Database schema changes.
- Authentication, authorization, or security changes.
- Changes to dependency lifetimes or ownership.
- Deployment or infrastructure changes.

When these changes are independent of other modifications, isolate them to make review, testing, and potential rollback easier.

**Important:** high impact alone does not justify splitting functionally inseparable changes. The separation must preserve system consistency.

### 2.4. Separate refactoring

Keep refactoring that does not alter observable behavior separate from features or fixes whenever it can be performed independently.

Recommended order:

1. Structural refactoring.
2. Feature implementation or bug fix.
3. Additional independent adjustments, if any.

If the refactoring is inseparable from the functional change, they may remain together, provided the commit has a clear purpose.

### 2.5. Tests and documentation

Prefer including automated tests directly related to a feature or fix in the same commit. Documentation needed to understand or use the change may also belong in that commit.

Separate independent tests or documentation changes.

**Rule:** do not create additional commits solely for tests or documentation when they are part of the same logical delivery, unless there is a technical or review reason to do so.

### 2.6. Formatting and cleanup

Do not mix purely cosmetic changes, such as broad formatting, import reorganization, or whitespace removal, with unrelated functional changes.

Group cosmetic changes into dedicated commits when they have a purpose of their own.

## 3. Message convention

Prefer the Conventional Commits format:

```text
<type>(<scope>): <description>
```

Recommended types:

| Type | Purpose |
|---|---|
| `feat` | New functionality |
| `fix` | Bug fix |
| `refactor` | Restructuring without changing behavior |
| `perf` | Performance optimization |
| `test` | Independent test changes |
| `docs` | Independent documentation changes |
| `style` | Formatting changes without functional impact |
| `build` | Dependencies and build system |
| `ci` | Pipelines and automation |
| `chore` | Maintenance that does not fit the other categories |

The type describes the nature of the change, not its priority or size.

Breaking changes may be indicated with `!` and explained in the commit body.

## 4. Workflow for organizing daily work

Before creating commits:

1. Review all modifications.
2. Identify the independent objectives represented by the changes.
3. Group files and code fragments by objective.
4. Assess dependencies between groups.
5. Separate independent refactoring, fixes, and features.
6. Verify that each group has a single purpose.
7. Stage only the changes belonging to the current group.
8. Review the staged diff and run the relevant validation.
9. Create a descriptive commit.
10. Repeat for the remaining groups.

Useful commands:

```bash
git status
git diff
git add -p
git diff --cached
git commit -m "type(scope): description"
```

`git add -p` allows separate fragments of the same file to be staged for different commits.

## 5. Practical example

Suppose a day of work includes:

- Restructuring singleton dependency resolution.
- Fixing a race condition during singleton initialization.
- Implementing a new configuration feature.
- Updating the tests related to each change.
- Correcting typos in unrelated documentation.

A reasonable separation would be:

**Commit 1**

```text
refactor(di): restructure singleton dependency resolution
```

Includes the refactoring and its tests.

**Commit 2**

```text
fix(di): prevent race condition during singleton initialization
```

Includes the fix and its concurrency tests.

**Commit 3**

```text
feat(config): add new configuration options
```

Includes the implementation and related tests.

**Commit 4**

```text
docs: correct documentation typos
```

Includes only the independent documentation changes.

This split is appropriate only if the commits can be applied in sequence without leaving inconsistent states.

## 6. Avoid excessive fragmentation

Do not create separate commits solely because:

- Different files were modified.
- Work touched different classes or methods.
- Tests were added for a functional change.
- Changes affected different architectural layers.
- An arbitrary number of changed lines was exceeded.

Likewise, do not group independent changes solely because:

- They were made on the same day.
- They affect the same file.
- They belong to the same module.
- They were developed during the same work session.

## 7. Final validation of each commit

Before committing, answer:

1. Do all changes pursue the same objective?
2. Is there a change that could be reviewed and reverted independently?
3. Are changes that need to coexist being artificially separated?
4. Does the commit preserve a technically consistent state?
5. Does the message accurately describe the change?

**Acceptance criterion:** a commit should represent the smallest logical unit of change that preserves functional cohesion, technical consistency, and usefulness for review and rollback.
