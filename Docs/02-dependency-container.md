# Dependency Container

`TAppContainer` is the application composition root. It owns dependency descriptors, HTTP framework component registries, and typed options registration.

Unit:

```text
Source/Core/Container.App.pas
```

Dependency injection attribute unit:

```text
Source/Core/Dependency.Attributes.pas
```

## Bootstrap and concurrent publication

Configure the root container on **one bootstrap thread**. Register services, options,
controllers, middlewares and attribute handlers, configure the options loader, then
call `Container.Prepare` before publishing the root to request/background workers.
Publish it using the application's normal thread-start or synchronization mechanism;
`Prepare` is not a replacement for safe publication of the root reference.

```pascal
Container := TAppContainer.Create;
// Register dependencies and configure options here, on the bootstrap thread.
Container.Prepare;
// Only now start workers or hand the root to the HTTP request pipeline.
```

`Prepare` materializes options and freezes registration. It is idempotent: subsequent
calls reuse the loaded options and do not reload them. It does not eagerly construct
all singleton services. Lazy resolution (including options access) before `Prepare`
does not itself freeze dependency registration; this remains a bootstrap-only activity,
not permission to resolve concurrently while modifying registrations. Options retain
their own restrictions on replacing a loader after materialization.

After preparation, do not mutate options, dependency descriptors, component registries,
or routes, even if an exposed object/list/property technically permits mutation.
Registration APIs reject changes after preparation. Treat the published configuration
as read-only; do not use descriptor setters to bypass this contract.

## Dependency lifetimes

Dependencies are application services registered by contract/port.

### Singleton

One instance is reused for the application lifetime. Concurrent resolutions publish
one fully constructed instance. Singleton construction is protected by a root-wide,
reentrant monitor, allowing a factory to resolve another singleton on the same thread.
A factory exception or `nil` result is not cached; a later resolution retries construction.
Factories must clean up any resources they allocate before failing.

Factories execute synchronously on the resolving thread. A singleton factory must not
start another thread and wait for it to resolve services from the same root: the factory
holds the singleton monitor, so that pattern can deadlock. Dependency resolution and
cycle/captive-scope tracking are synchronous, same-thread operations; do not move a
resolver to another thread or retain it for deferred construction.

Safe publication does **not** make a singleton's mutable state thread-safe. Each service
must synchronize its own mutable state or be immutable.

```pascal
Container.AddSingleton<IClock, TSystemClock>;
```

### Scoped

One instance is reused within a request scope.

```pascal
Container.AddScoped<IAuthService, TAuthService>;
```

### Transient

A new instance is created every time the dependency is resolved.

```pascal
Container.AddTransient<IEmailSender, TSmtpEmailSender>;
```

### Factory

Use factories when construction needs custom logic, configuration values such as
strings or integers, external library objects, or runtime implementation selection.
The generic API expresses the lifetime in the method name:

```pascal
Container.AddSingletonFactory<IMyService, TMyService>(
  function(const Resolve: TDependencyResolver): TObject
  begin
    Result := TMyService.Create;
  end
);
```

The factory receives a `TDependencyResolver` to resolve other registered dependencies.
`TDependency` can be an interface; only `TImplementation` has a `class` constraint.
The factory still returns `TObject`: `TImplementation` does not validate or cast
its result.

- `AddSingletonFactory`: runs once, with the instance reused and owned by the root container. A singleton cannot resolve a scoped dependency during construction.
- `AddScopedFactory`: runs once per scope; different scopes receive different instances.
- `AddTransientFactory`: runs on every resolution. Transients resolved from a scope are tracked and freed by that scope.

The original API remains available for compatibility and low-level registration:

```pascal
Container.AddFactory(TypeInfo(IMyService), Factory, dlScoped);
```

## Interface aliases

An alias exposes an existing principal interface registration through another interface
contract without creating a second descriptor or an additional owner:

```pascal
type
  // Both interfaces declare their own GUID; neither inherits from the other.
  TService = class(TComponent, IPrimaryService, ISecondaryService)
    // Implement both contracts. TComponent does not reference-count its lifetime.
  end;

Container.AddSingleton<IPrimaryService, TService>;
Container.AddAlias<ISecondaryService, IPrimaryService>;
// Equivalent low-level overload (use instead, not in addition):
// Container.AddAlias(TypeInfo(ISecondaryService), TypeInfo(IPrimaryService));
Container.Prepare;
```

The first argument is the alias; the second is the principal contract. Both must be
non-nil interface type information. The principal must already have a direct dependency
registration. Self-aliases, alias chains, duplicate aliases, and aliases that collide
with an existing normal registration are rejected. Normal registrations (including
factories) cannot overwrite an alias either. Register aliases on the bootstrap thread,
before `Prepare`; both overloads reject registration after preparation. As with other
registrations, do not mutate aliases concurrently with resolution or preparation.

`GetDescriptor(TypeInfo(ISecondaryService))` returns the principal descriptor, not an
alias-owned descriptor. Replacing the principal registration on the root **before
`Prepare`** also changes what its aliases resolve; aliases refer to the principal key,
not a snapshot of its old descriptor. Do not retain an old descriptor across replacement.

Aliases preserve the principal lifetime and ownership:

- **Singleton:** alias and principal resolve to the same object owned by the root.
- **Scoped:** both keys share one cache entry in each scope, regardless of which is
  resolved first; different scopes receive different objects. Root resolution remains
  invalid for scoped services.
- **Transient:** every resolution creates a new object, including alias resolutions.
  Transients resolved through a scope are tracked and freed by that scope.

An alias never owns or separately frees an instance. Resolution through an alias also
participates in the usual cycle and captive-scope checks. `Resolve` returns `TObject`,
not a typed interface, and does not by itself guarantee that the object implements the
alias contract. Constructor injection checks `Supports` for the requested interface
GUID and creates a `TValue` with that exact parameter type; an incompatible object is
rejected before invoking the constructor. A cached singleton interface `InstanceValue`
is only reusable when its contract matches the requested parameter, not merely because
an alias shares its descriptor.

Use container-owned, non-reference-counted implementations such as `TComponent` with
`nil` as component owner; do not combine component ownership with container ownership.
Interface references do not extend these objects' lifetimes: release consumers and all
references before disposing their owning scope/root. No reference may survive its
owner, and the root must outlive its scopes.

## Constructor injection

The container creates dependencies and framework components through public `Create` constructors.

Constructor parameters are resolved from registered dependencies by RTTI. Supported injectable parameter kinds are:

- class types;
- interface types, including closed generic interfaces such as `IOptions<TLoggerOptions>`.

Example:

```pascal
type
  TJwtService = class(TInterfacedObject, IJwtService)
  private
    FOptions: IOptions<TJwtOptions>;
  public
    constructor Create(const AOptions: IOptions<TJwtOptions>);
  end;
```

## Selecting a constructor with `[Inject]`

When a class has multiple public `Create` constructors, mark the constructor intended for dependency injection with `[Inject]`.

Unit:

```pascal
uses
  Dependency.Attributes;
```

Example:

```pascal
uses
  Dependency.Attributes,
  Options.Port;

type
  TJwtService = class(TInterfacedObject, IJwtService)
  public
    constructor Create; overload;

    [Inject]
    constructor Create(const AOptions: IOptions<TJwtOptions>); overload;
  end;
```

The attribute is declared as:

```pascal
InjectAttribute = class(TCustomAttribute);
```

### Constructor selection rules

`TAppContainer` uses these rules:

1. It scans public constructors named `Create` declared on the concrete implementation type.
2. If exactly one constructor is marked with `[Inject]`, that constructor is used.
3. If more than one constructor is marked with `[Inject]`, the container raises an error.
4. If none is marked and there is exactly one public `Create` constructor, that constructor is used.
5. If none is marked and there are multiple public `Create` constructors, the container raises an error asking you to mark one with `[Inject]`.
6. If no public `Create` constructor is discovered by RTTI, the component falls back to `AImplementationType.Create`.

This avoids guessing based on the constructor with the largest parameter list.

## Resolving options through constructor injection

Options are injected as `IOptions<TOptions>`.

```pascal
constructor TLogger.Create(const AOptions: IOptions<TLoggerOptions>);
begin
  inherited Create;
  FOptions := AOptions.Value;
end;
```

The options registry stores a correctly typed value for each closed generic interface, for example:

```pascal
IOptions<TLoggerOptions>
```

This allows RTTI constructor invocation to receive the exact interface type expected by the constructor.

## Request scopes

`TContainerScope` stores scoped instances and tracks transients created during a request.

The router creates a scope per request and passes it through `TContext`.

Singleton dependencies are resolved from the root container. Scoped dependencies must be resolved from a request scope.

A scope is **not shareable concurrently**. Its instance cache and transient ownership
are local to one request/operation; different workers may use different scopes at the
same time. Repeated resolution within one scope returns the same scoped instance;
different live scopes receive different instances. Dispose the scope only after all
work using its services has completed.

The root must outlive every scope and all workers resolving through it. For background
work, create and dispose a dedicated scope for that operation; never capture a request
scope or request-scoped service for work that outlives the request.

A singleton cannot capture a scoped service during construction, directly or through
transient/factory resolutions. This also applies when a factory closes over an existing
scope and requests an already cached scoped instance. Same-thread cycles are rejected,
and resolution tracking unwinds after exceptions so later resolutions can retry.
These checks do not replace correct application ownership or detect arbitrary references
assigned after construction.

These guarantees concern the dependency-container core. They are not a complete
thread-safety audit of the router, HTTP server, logging, middleware, or other framework
components.

## HTTP framework components

These are not dependency registrations:

```pascal
Container.AddController(TUsersController);
Container.Use(TExceptionMiddleware);
Container.AddAttributeHandler(TRequireRoleHandler);
```

They are concrete framework components. The framework creates them with constructor injection using the current request scope.

## Public API summary

```pascal
Container.AddSingleton<IDependency, TImplementation>;
Container.AddScoped<IDependency, TImplementation>;
Container.AddTransient<IDependency, TImplementation>;
Container.AddSingletonFactory<IDependency, TImplementation>(Factory);
Container.AddScopedFactory<IDependency, TImplementation>(Factory);
Container.AddTransientFactory<IDependency, TImplementation>(Factory);
Container.AddFactory(TypeInfo(IDependency), Factory, dlScoped);

Container.AddController(TControllerClass);
Container.AddControllers([TOneController, TAnotherController]);

Container.Use(TMiddlewareClass);
Container.Use([TFirstMiddleware, TSecondMiddleware]);

Container.AddAttributeHandler(THandlerClass);
Container.AddAttributeHandlers([TOneHandler, TAnotherHandler]);

Container.AddOptions<TOptions>;
Container.Prepare; // Finish single-threaded bootstrap before publication.
```

## Common errors

### Multiple constructors without `[Inject]`

If a type has more than one public `Create` constructor, mark the injectable one:

```pascal
[Inject]
constructor Create(const ARepository: IUserRepository; const ALogger: ILogger);
```

### Missing dependency registration

Every constructor parameter must be registered or provided by framework infrastructure.

For example, this constructor requires `ILogger` to be registered:

```pascal
constructor Create(const ALogger: ILogger);
```

Registration:

```pascal
Container.AddSingleton<ILogger, TLogger>;
```

### Missing options registration

A constructor that asks for:

```pascal
IOptions<TLoggerOptions>
```

requires:

```pascal
Container.AddOptions<TLoggerOptions>;
```

unless the framework registers that options type by default.
