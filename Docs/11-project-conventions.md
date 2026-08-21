# Project Conventions

This document describes conventions used in the repository.

## Framework code vs application code

Framework code lives under `Source` and is organized into three top-level areas:

```text
Source/Core/
Source/Http/
Source/Dto/
```

Application/demo code lives under `Example`.

`Example` is reserved for:

- application code;
- test/demo code;
- project-specific controllers or services.

If a unit is used directly by `TAppContainer`, routing, middleware, DTO binding or core infrastructure, it belongs under `Source`.

## Ports

Contracts are named as ports where appropriate:

```text
Logger.Port.pas
Dto.Port.pas
Http.Router.Port.pas
```

Dependency registrations should target ports/interfaces:

```pascal
Container.AddScoped<IAuthService, TAuthService>;
```

## Controllers

Controllers:

- must implement `IController`;
- are registered with `AddController` or `AddControllers`;
- are not DI dependencies;
- are created by the framework with constructor injection.

## Middlewares

Middlewares:

- must implement `IMiddleware`;
- can be global via `Use`;
- can be attached with `[UseMiddleware]`;
- are created as framework components, not dependency registrations.

## Attribute handlers

Endpoint attribute handlers:

- must implement `IEndpointAttributeHandler`;
- are registered with `AddAttributeHandler`;
- should keep attributes as metadata and behavior in handlers.

## Options

Options:

- are records;
- are exposed as `IOptions<T>`;
- are loaded once from `TAppOptions`;
- are registered by section name using `AddOptions<T>('FieldName')`.

## Documentation

Documentation should be written in English and split by topic. Prefer small focused files over a single large guide.
