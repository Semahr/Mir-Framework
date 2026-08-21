# Controllers and Routing

Controllers are discovered from classes registered in `TAppContainer`.

Relevant units:

```text
Http/Controllers/Http.Controller.Port.pas
Http/Attributes/Http.Attributes.pas
Http/Routing/Http.ControllerScanner.pas
Http/Routing/Http.RouteDescriptor.pas
Http/Routing/Http.Router.pas
Http/Routing/Http.ActionInvoker.pas
```

## Controller contract

Every controller must implement `IController`.

```pascal
type
  TUsersController = class(TInterfacedObject, IController)
  end;
```

## Registration

Controllers are HTTP framework components, not dependency registrations.

```pascal
Container.AddController(TUsersController);
```

Batch registration:

```pascal
Container.AddControllers([
  TUsersController,
  TAuthController
]);
```

## Routes

Use `RouteAttribute` at controller level:

```pascal
[Route('/users')]
TUsersController = class(TInterfacedObject, IController)
end;
```

Use HTTP method attributes at action level:

```pascal
[Get]
function GetAll: TUsersDto;

[Get('/:id')]
function GetById([FromRoute] const Id: Integer): TUserDto;

[Post]
function Create([FromBody] const Request: TCreateUserDto): TUserDto;
```

Supported method attributes:

- `[Get]`
- `[Post]`
- `[Put]`
- `[Patch]`
- `[Delete]`

## Route matching

The router matches by:

1. HTTP method;
2. route path pattern;
3. route parameters using `:name` syntax.

Example:

```pascal
[Get('/:id')]
```

matches:

```text
GET /users/123
```

and stores:

```text
id = 123
```

## Controller creation

Controllers are not resolved from the DI registry. They are created by the framework using `CreateComponentInstance`, so constructor injection is still available.

```pascal
constructor TUsersController.Create(const AUserService: IUserService);
```

`IUserService` must be registered as a dependency.
