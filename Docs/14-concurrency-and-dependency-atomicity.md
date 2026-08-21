# Concurrency and Dependency Atomicity Analysis

This document captures the current concurrency concerns in the framework and defines the intended direction for future changes. It focuses only on the framework code under `Source/`.

## Current conclusion

The framework is designed to support concurrent HTTP requests, but it does not yet fully guarantee thread-safe dependency resolution.

The desired target is:

> The framework should guarantee atomic and thread-safe dependency resolution across concurrent requests. A singleton must be created only once, scopes must remain isolated per request, and framework-owned metadata should become immutable after application startup.

This target does **not** mean that the framework will automatically make every singleton's internal logic thread-safe. Singleton instances are shared between requests, so their own mutable state still requires careful design.

## Agreed guarantee level

The framework should implement **resolution atomicity**.

That means:

- resolving dependencies from multiple request threads must not corrupt container state;
- lazy singletons must be initialized exactly once;
- scoped dependencies must remain isolated per request/scope;
- framework metadata such as dependency descriptors, controller types, middleware descriptors, attribute handler types, options registrations, and route descriptors should not change while requests are being served.

The framework should not automatically serialize every method call made on a singleton instance. That would require a much larger model involving proxies, interceptors, synchronized wrappers, or explicit opt-in synchronization.

## Important distinction: resolution vs. object behavior

Dependency resolution is the process of obtaining an instance:

```pascal
Service := Container.Resolve(TypeInfo(IService));
```

Object behavior is what happens after the instance is returned:

```pascal
Service.DoSomething;
```

The framework can reasonably guarantee that `Resolve` is safe when called from multiple threads. However, once the same singleton instance is returned to several requests, those requests may call its methods at the same time.

For example:

```text
Request A -> Resolve(IService) -> Singleton instance #1
Request B -> Resolve(IService) -> Singleton instance #1
Request C -> Resolve(IService) -> Singleton instance #1
```

All three requests receive the same object. If that object modifies internal fields without synchronization, the framework cannot protect those field updates unless it intercepts or wraps the object's method calls.

Therefore, the future framework contract should be:

> The framework guarantees safe singleton creation and resolution. Singleton instances are shared between requests. If a singleton keeps mutable internal state, that state must be designed to be thread-safe, or the dependency should use a scoped/transient lifetime instead.

## Meaning of immutable, stateless, and explicitly synchronized

These terms describe whether a singleton can safely be shared by multiple request threads.

### Immutable

An object is immutable when its observable state does not change after construction.

Example conceptually:

```pascal
TAppSettings = class
private
  FBaseUrl: string;
public
  constructor Create(const ABaseUrl: string);
  property BaseUrl: string read FBaseUrl;
end;
```

If `FBaseUrl` is assigned only in the constructor and never changed afterwards, multiple threads can safely read it.

### Stateless

An object is stateless when it does not store request-specific or operation-specific data in fields.

Example conceptually:

```pascal
TPasswordHasher = class
public
  function Hash(const APassword: string): string;
end;
```

If `Hash` only uses local variables and does not modify object fields, the same instance can usually be shared safely.

### Explicitly synchronized

An object is explicitly synchronized when it protects shared mutable state with synchronization primitives such as `TCriticalSection`, `TMonitor`, or atomic operations.

Example conceptually:

```pascal
TSharedCounter = class
private
  FLock: TObject;
  FValue: Integer;
public
  procedure Increment;
end;
```

Where `Increment` enters a lock before modifying `FValue`.

This type of synchronization belongs inside the singleton itself, unless the framework introduces a future opt-in synchronized singleton/proxy model.

## Current findings in `Source/`

## A. Lazy singleton creation is not atomic

Location:

```text
Source/Core/Container.App.pas
```

Current logic:

```pascal
if SingletonDescriptor.Instance = nil then
  SingletonDescriptor.Instance := CreateInstance(Descriptor, Self);

Exit(SingletonDescriptor.Instance);
```

This is not thread-safe.

If two request threads resolve the same singleton for the first time, both can observe `Instance = nil` and both can create an instance. The last assignment wins, and the other instance may be leaked or may have already executed constructor side effects.

Possible failure flow:

```text
Thread A: Instance is nil
Thread B: Instance is nil
Thread A: creates singleton A
Thread B: creates singleton B
Thread A: assigns Instance := singleton A
Thread B: assigns Instance := singleton B
```

Result:

- the singleton may be constructed more than once;
- constructor side effects may run more than once;
- one instance can be lost;
- the container cannot truthfully guarantee singleton uniqueness under load.

### Required future change

Singleton creation must be protected with synchronization.

The preferred design should avoid a single global lock where possible, but correctness is more important than fine-grained performance at this stage.

Possible implementation directions:

1. Container-level lock around singleton creation.
2. Per-singleton descriptor lock.
3. Double-checked locking with a lock protecting the second check and assignment.

The framework must ensure that only one thread creates and publishes the singleton instance.

## B. `FResolutionStack` is global and not thread-safe

Location:

```text
Source/Core/Container.App.pas
```

Current field:

```pascal
FResolutionStack: TList<PTypeInfo>;
```

### What `FResolutionStack` is for

`FResolutionStack` is used to detect circular dependencies during object construction.

For example, suppose the dependencies are:

```text
A depends on B
B depends on C
C depends on A
```

When resolving `A`, the container enters `A` into the stack:

```text
[A]
```

Then it needs `B`:

```text
[A, B]
```

Then it needs `C`:

```text
[A, B, C]
```

Then `C` needs `A`. Since `A` is already in the stack, the container detects a circular dependency:

```text
A -> B -> C -> A
```

This is useful because otherwise dependency construction could recurse forever or fail with a less helpful error.

### Why the current design is unsafe

The current stack is stored in the root container. The root container is shared by all requests.

That means two concurrent requests may use the same stack at the same time:

```text
Thread A resolving IServiceA: pushes IServiceA
Thread B resolving IServiceB: pushes IServiceB into the same list
Thread A resolving IServiceC: sees IServiceB even though it belongs to another request
```

This can cause:

- false circular dependency errors;
- corrupted resolution paths;
- incorrect removals from the stack;
- unsafe concurrent access to `TList<PTypeInfo>`.

### Required future change

The resolution stack should not be global mutable state.

Better directions:

1. Make the stack local to a single resolution operation.
2. Pass a resolution context through nested `Resolve` / `CreateInstance` calls.
3. Store the stack per scope/request.
4. Use thread-local storage only if the design remains simple and predictable.

The cleanest design is likely a resolution context object passed internally during construction.

Conceptually:

```text
Resolve(IService)
  -> creates TResolutionContext
  -> CreateInstance(..., Context)
  -> nested resolves reuse the same Context
```

Each request/thread then has its own resolution path.

## C. Dependency descriptors are read without protection

Location:

```text
Source/Core/Container.App.pas
```

Current field:

```pascal
FDescriptors: TObjectDictionary<PTypeInfo, TDependencyDescriptor>;
```

The framework reads descriptors during request processing:

```pascal
if not FDescriptors.TryGetValue(ATypeInfo, Result) then
  raise ...
```

The desired application model is that dependency registration happens only during startup, before the server begins handling requests.

That model is valid, but the framework should enforce it formally.

## Freezing the container

The framework should introduce a frozen state.

Conceptually:

```text
Startup phase:
  - register options
  - register controllers
  - register middlewares
  - register dependencies
  - build routes
  - freeze container

Runtime phase:
  - resolve dependencies
  - dispatch requests
  - no more registrations allowed
```

Once frozen, registration methods should reject changes.

Examples of methods that should not be callable after freeze:

- `AddSingleton`
- `AddScoped`
- `AddTransient`
- `AddFactory`
- `RegisterInstance`
- `AddOptions`
- `SetOptionsLoader`
- `AddController`
- `AddControllers`
- `Use`
- `AddAttributeHandler`
- `AddAttributeHandlers`

This makes framework metadata effectively immutable during request processing.

### What immutable means here

Immutable means the collection or object is not modified after a certain point.

For framework metadata, this means:

- descriptors are built during startup and then no longer changed;
- route descriptors are created during server composition and then only read;
- controller/middleware/attribute handler registrations are finalized before serving requests;
- options registrations are finalized before serving requests.

Read-only shared data is much safer under concurrency than mutable shared data.

### Required future change

Introduce an explicit freeze step.

Possible directions:

1. `TAppContainer.Freeze` called by `THttpComposition.CreateDefaultServer`.
2. `THttpServer.Start` freezes the container indirectly.
3. A separate application builder object owns registration, then builds an immutable runtime container.

The least disruptive option is probably to add `Freeze` to `TAppContainer` and have HTTP composition call it before the server starts handling requests.

## D. `TOptionsRegistry` is not thread-safe

Location:

```text
Source/Core/Options.Registry.pas
```

Current mutable fields:

```pascal
FSectionMaterializers: TList<TOptionsSectionMaterializer>;
FInstances: TObjectDictionary<PTypeInfo, TObject>;
FRootValue: TJSONObject;
FLoaded: Boolean;
```

Current loading logic:

```pascal
if FLoaded then
  Exit;

FRootValue := FRootLoader();
...
FLoaded := True;
```

This is not atomic.

Two threads could attempt to load or materialize options at the same time. Also, `AddOptions<T>` can materialize options immediately if `FLoaded` is already true.

### Required future change

Options loading and materialization should be protected.

Possible directions:

1. Ensure options are fully loaded during startup before freeze.
2. Prevent `AddOptions<T>` after freeze.
3. Protect `EnsureLoaded` with a lock.
4. Ensure options instances are published only once.

The recommended direction is:

- options are registered during startup;
- `EnsureLoaded` is called before or during freeze;
- after freeze, options are read-only;
- `EnsureLoaded` remains guarded to be safe.

## Request scope isolation

Location:

```text
Source/Core/Container.Scope.pas
Source/Http/Http.Router.pas
```

The router creates a new scope per request:

```pascal
var Scope := FContainer.CreateScope;
var Context := TContext.Create(ARequest, Scope);
```

That gives the framework the intended lifetime behavior:

```text
Request A -> Scope A -> scoped instances A
Request B -> Scope B -> scoped instances B
```

### What it means to formally impose one scope per request

A framework can impose this rule by owning scope creation and disposal internally.

The current router already does this for normal HTTP dispatch. The scope is created inside `InvokeRoute` and passed through the request context. User code does not need to manually create the request scope for standard controller execution.

To make this more formal, the framework should:

1. Continue creating a new `TContainerScope` inside each request dispatch.
2. Avoid exposing request scopes as long-lived reusable objects.
3. Document that `TContainerScope` is request-owned and must not be shared between threads.
4. Optionally add runtime safeguards in debug mode, such as recording the creating thread ID and rejecting use from another thread.
5. Avoid APIs that encourage manually storing and reusing a scope globally.

A strict runtime check could conceptually work like this:

```text
Scope created on Thread A
Scope.Resolve called on Thread A -> allowed
Scope.Resolve called on Thread B -> rejected
```

This would make scope ownership explicit. However, this may be too restrictive if the framework later supports asynchronous work that intentionally crosses threads.

For now, the most practical rule is:

> The framework owns request scope creation during HTTP dispatch. A request scope is intended to be used only for the lifetime of that request and not shared between concurrent requests.

## Route immutability

Location:

```text
Source/Http/Http.Router.pas
Source/Http/Http.Composition.pas
```

Routes are built by the scanner during server composition:

```pascal
Routes := Scanner.Execute(AContainer.GetControllerTypes);
```

Then the router receives the route list:

```pascal
Result := TRouter.Create(ARoutes, ActionInvoker, AContainer);
```

During dispatch, routes are only iterated:

```pascal
for var Route in FRoutes do
```

This is safe if the route list is immutable after router creation.

To make this guarantee explicit, the framework should treat routes as runtime metadata generated at startup. No route should be added, removed, or modified while requests are being served.

Possible future improvements:

1. Store routes in an array instead of `TObjectList<TRouteDescriptor>` after composition.
2. Make route descriptor state read-only after scanning.
3. Freeze routes as part of server/router creation.

## Proposed future framework contract

The framework should eventually document and enforce the following contract:

1. Application registration happens during startup only.
2. The container is frozen before requests are handled.
3. After freeze, dependency registrations, options registrations, controller registrations, middleware registrations, attribute handler registrations, and routes are immutable.
4. Dependency resolution is thread-safe.
5. Lazy singleton initialization is atomic and happens at most once.
6. Scoped dependencies are isolated per request scope.
7. Request scopes are framework-owned during HTTP dispatch and are not meant to be shared between concurrent requests.
8. Singleton instances are shared across requests.
9. The framework does not automatically serialize method calls on singleton instances.
10. A singleton with mutable internal state must be designed as thread-safe or registered with a non-singleton lifetime.

## Suggested implementation priorities

### Priority 1: Make singleton initialization atomic

This is the most direct correctness issue.

### Priority 2: Replace global `FResolutionStack`

The circular dependency detection stack should become per-resolution rather than root-container global state.

### Priority 3: Add container freeze

Registrations should be allowed during startup and rejected during runtime.

### Priority 4: Make options loading/finalization safe

Options should be registered and materialized during startup/freeze, then treated as read-only during runtime.

### Priority 5: Make route immutability explicit

Routes are already conceptually immutable. The code should make that guarantee harder to accidentally break.

## Open design decisions

Before implementation, these decisions should be made:

1. Should singleton initialization use one container-wide lock or one lock per singleton descriptor?
2. Should `Freeze` be called manually by application code, automatically by `THttpComposition`, or automatically by `THttpServer.Start`?
3. Should scopes enforce same-thread usage at runtime, or should this remain a documented rule?
4. Should options be eagerly materialized during freeze?
5. Should route storage remain as `TObjectList<TRouteDescriptor>` or become an immutable array owned by the router?
6. Should the framework later support an opt-in synchronized singleton model, such as `AddSynchronizedSingleton`, or keep synchronization entirely inside user services?
