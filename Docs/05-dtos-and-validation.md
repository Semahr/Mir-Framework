# DTOs and Validation

DTO support is provided through DTO ports, binding and validation units.

Relevant areas:

```text
Dto/Ports/Dto.Port.pas
Dto/Binding/
Dto/Validation/
Dto/Attributes/
```

## DTO contract

Request/response DTOs should implement the DTO contract used by the framework.

The framework expects DTO objects to be interface-based through `IDto`.

## Body binding

Controller actions can receive DTOs from request body using parameter attributes:

```pascal
[Post]
function Create([FromBody] const Request: TCreateUserDto): TUserDto;
```

The body binder parses JSON into DTO instances and validates them using DTO metadata.

## Validation attributes

DTO validation is based on attributes and validators under:

```text
Dto/Validation/Validators/
```

Existing validator categories include:

- required values;
- strings;
- numbers;
- booleans;
- dates.

## Response DTOs

If a controller action returns an object implementing `IDto`, the router serializes it to JSON:

```pascal
function Profile: TUserProfileDto;
```

The router maps the object to:

```pascal
TResponse.Json(...)
```

## Invalid return values

A route action should return one of:

- `TResponse`;
- an object implementing `IDto`;
- `nil` or empty value for no content.

Invalid return types raise an exception.
