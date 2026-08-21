# Custom Attributes

Custom endpoint attributes are supported through attribute handlers.

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
