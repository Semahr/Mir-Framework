# Architecture Overview

BackendFramework is organized so framework code lives outside `Src`, while `Src` is reserved for application code, examples, experiments, or tests.

## Main areas

```text
Core/         Dependency container, options, helpers and framework infrastructure
Http/         HTTP server, routing, context, parameters and middleware
Dto/          DTO contracts, binding and validation
Example/      Example application code
Docs/         Documentation
Config/       Default runtime configuration files
```

## Framework responsibilities

The framework provides:

- a dependency container with singleton, scoped and transient registrations;
- request scopes;
- constructor injection;
- attribute-based controllers and routes;
- parameter binding;
- DTO parsing and validation;
- response mapping;
- middleware pipeline support;
- custom endpoint attribute handlers;
- typed options through `IOptions<T>`.

## Application responsibilities

Application code is expected to define:

- concrete controllers;
- application services and ports;
- DTOs;
- additional options sections;
- external services such as logging implementations;
- custom middlewares;
- custom endpoint attributes and handlers;
- dependency registrations.

## Request lifecycle

```mermaid
sequenceDiagram
    participant Request
    participant Router
    participant Scope
    participant Pipeline
    participant Invoker
    participant Controller

    Request->>Router: Dispatch
    Router->>Router: Match route
    Router->>Scope: Create request scope
    Router->>Pipeline: Execute global + route middlewares
    Pipeline->>Pipeline: Execute attribute handlers
    Pipeline->>Invoker: Invoke endpoint
    Invoker->>Controller: Create controller + bind params
    Controller-->>Invoker: Return value
    Invoker-->>Pipeline: TValue
    Pipeline-->>Router: TResponse
```

## Important separation

Dependency registrations are not the same as HTTP framework component registrations.

Dependencies are registered by contract/port:

```pascal
Container.AddScoped<IAuthService, TAuthService>;
```

HTTP framework components are registered by class:

```pascal
Container.AddController(TUsersController);
Container.Use(TLoggingMiddleware);
Container.AddAttributeHandler(TRequireRoleHandler);
```

Controllers, middlewares and endpoint attribute handlers are created by the framework using constructor injection, but they are not registered as DI dependencies themselves.
