# Custom Attributes

Custom attributes can be used in three ways:

- Inherit from `UseMiddlewareAttribute` to select an existing middleware under a
  custom name, without modifying that middleware. See
  [Custom middleware attributes](./08-middlewares.md#custom-middleware-attributes)
  for a complete `ProtectedAttribute` example. No attribute handler is required.
- Declare metadata that a middleware reads with `TContext.TryGetAttribute<T>`.
  See [Reading endpoint metadata](./08-middlewares.md#reading-endpoint-metadata).
- Register an `IEndpointAttributeHandler` to interpret an attribute during the
  attribute-handler stage. The rest of this page describes this approach.

Relevant unit:

```text
Http/EndpointAttributes/Http.EndpointAttributeHandler.Port.pas
```

## Attribute handler contract

```pascal
IEndpointAttributeHandler = interface
  function Supports(const AAttribute: TCustomAttribute): Boolean;

  function Invoke(
    const AAttribute: TCustomAttribute;
    const AContext: TContext;
    const ANext: TNextDelegate
  ): TResponse;
end;
```

## Design

Attributes should describe metadata. Handlers execute behavior.

Example attribute:

```pascal
type
  RequireRoleAttribute = class(TCustomAttribute)
  private
    FRole: string;
  public
    constructor Create(const ARole: string);
    property Role: string read FRole;
  end;
```

Example handler:

```pascal
type
  TRequireRoleHandler = class(TInterfacedObject, IEndpointAttributeHandler)
  public
    function Supports(const AAttribute: TCustomAttribute): Boolean;
    function Invoke(
      const AAttribute: TCustomAttribute;
      const AContext: TContext;
      const ANext: TNextDelegate
    ): TResponse;
  end;
```

## Registration

```pascal
Container.AddAttributeHandler(TRequireRoleHandler);
```

Batch registration:

```pascal
Container.AddAttributeHandlers([
  TRequireRoleHandler,
  TRequirePermissionHandler
]);
```

## Usage

```pascal
[Get]
[RequireRole('admin')]
function GetAdminUsers: TUsersDto;
```

## Execution

The scanner stores controller and action attributes in the route descriptor. The middleware pipeline executes registered handlers for supported attributes.

Handlers are created by the framework using constructor injection.
