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

## Custom middleware attributes

You can give a middleware declaration an application-specific name by inheriting
from `UseMiddlewareAttribute`. This requires no changes to the framework or the
middleware implementation.

For example, define this unit in your application's HTTP presentation layer.
`App.AuthMiddleware` is a placeholder for the application unit that declares your
`TAuthMiddleware`; replace it with the actual unit name:

```pascal
unit App.Security.Attributes;

interface

uses
  Http.Middleware.Attributes;

type
  ProtectedAttribute = class(UseMiddlewareAttribute)
  public
    constructor Create;
  end;

implementation

uses
  App.AuthMiddleware; // Replace with the unit that declares TAuthMiddleware.

constructor ProtectedAttribute.Create;
begin
  inherited Create(TAuthMiddleware);
end;

end.
```

Add `App.Security.Attributes` to the controller unit's `uses` clause, then replace
`[UseMiddleware(TAuthMiddleware)]` with your custom attribute:

```pascal
[Post('/activar-reporte')]
[ProtectedAttribute]
[StatusCode(201)]
function ActivateReport(
  [FromBody] const ARequestDto: TActivateReportDto
): TSuccessDto;
```

You can also apply the attribute to a controller class to select the middleware
for all its discovered routes. Since `protected` is a Delphi reserved word, use
`[ProtectedAttribute]` or the escaped short form `[&Protected]`, not `[Protected]`.
Alternatively, name the class `AuthorizeAttribute` and use `[Authorize]`.

The controller scanner checks `Attribute is UseMiddlewareAttribute`, so it also
recognizes descendants. It reads the inherited `MiddlewareType` and `Order`
properties and adds the usual middleware descriptor. `TAuthMiddleware` must still
implement `IMiddleware`; its dependencies are resolved through the normal
constructor-injection mechanism. To specify an order, pass the optional second
argument to the base constructor, for example `inherited Create(TAuthMiddleware, 10)`.

No `AddAttributeHandler` registration is needed. You also do not need to register
the same middleware with `Container.Use` for this declaration to take effect.
This attribute adds a middleware; it does not replace or exclude global
middlewares, and registering the same middleware in multiple scopes can execute
it more than once.

This differs from a plain metadata attribute queried with
`TContext.TryGetAttribute<T>`: a `UseMiddlewareAttribute` descendant selects a
middleware automatically, whereas plain metadata has no effect unless a
middleware or handler explicitly interprets it. The `ProtectedAttribute` above
is application-defined, not a built-in authentication policy.

## Reading endpoint metadata

Middlewares can inspect custom attributes with `TContext.TryGetAttribute<T>(out AAttribute)`:

```pascal
function TryGetAttribute<T: TCustomAttribute>(out AAttribute: T): Boolean;
```

For example, define a metadata attribute in your application (with
`System.SysUtils` in the unit's `uses` clause):

```pascal
type
  AuthenticationAttribute = class(TCustomAttribute)
  private
    FRequired: Boolean;
  public
    constructor Create(const ARequired: Boolean);
    property Required: Boolean read FRequired;
  end;

constructor AuthenticationAttribute.Create(const ARequired: Boolean);
begin
  inherited Create;
  FRequired := ARequired;
end;
```

Apply `[Authentication(True)]` or `[Authentication(False)]` to a controller or
action, then read the policy inside your middleware's `Invoke` method:

```pascal
var
  Attribute: AuthenticationAttribute;
begin
  if AContext.TryGetAttribute<AuthenticationAttribute>(Attribute) then
  begin
    if not Attribute.Required then
      Exit(ANext());
  end;

  // Authenticate here. No matching metadata means the middleware uses its default.
end;
```

`AuthenticationAttribute` above is an application-defined attribute with a `Required`
Boolean property, not a built-in security policy.

`TryGetAttribute<T>` searches action attributes first, then controller attributes.
It matches both `T` and descendants of `T`. It returns `False` and sets the output
parameter to `nil` when no match exists. Within each scope, the first matching
attribute wins; avoid conflicting declarations in the same scope.

To support both anonymous and protected actions, derive both attributes from the
same policy attribute and query that base type. This lets an explicit action policy
(for example, `Required = True`) override the controller policy (`Required = False`).
Looking only for an anonymous marker would not provide that two-way override.

Attributes are borrowed RTTI objects: do not free or modify the returned instance.
The lookup does not skip middlewares or change pipeline order; each middleware
must explicitly interpret its metadata. Existing two-argument `TContext.Create`
calls remain valid and have no metadata unless it is supplied.

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
