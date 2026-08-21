# Middlewares

Middlewares are HTTP framework components that wrap endpoint execution.

Relevant units:

```text
Http/Middleware/Http.Middleware.Port.pas
Http/Middleware/Http.Middleware.Descriptor.pas
Http/Middleware/Http.Middleware.Attributes.pas
Http/Middleware/Http.Middleware.Pipeline.pas
```

## Contract

```pascal
IMiddleware = interface
  function Invoke(const AContext: TContext; const ANext: TNextDelegate): TResponse;
end;
```

A middleware can:

- run logic before the endpoint;
- run logic after the endpoint;
- short-circuit and return a response without calling `ANext`.

## Global middlewares

Register global middlewares with `Use`:

```pascal
Container.Use(TExceptionMiddleware);
Container.Use(TLoggingMiddleware);
```

Batch registration:

```pascal
Container.Use([
  TExceptionMiddleware,
  TLoggingMiddleware
]);
```

Global middlewares run for every matched route.

## Controller and route middlewares

Use attributes:

```pascal
[UseMiddleware(TAuthMiddleware)]
TUsersController = class(TInterfacedObject, IController)
end;
```

Route-level:

```pascal
[Get]
[UseMiddleware(TAdminOnlyMiddleware)]
function GetAll: TUsersDto;
```

## Execution order

The current order is:

1. global middlewares;
2. controller middlewares;
3. route middlewares;
4. endpoint attribute handlers;
5. controller action.

## Construction

Middlewares are not dependency registrations. The framework creates them as components using constructor injection.

If a middleware needs application dependencies, register those dependencies normally:

```pascal
Container.AddScoped<IAuthService, TAuthService>;
Container.Use(TAuthMiddleware);
```

Then:

```pascal
constructor TAuthMiddleware.Create(const AAuthService: IAuthService);
```
