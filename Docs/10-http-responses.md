# HTTP Responses

HTTP response behavior is handled by the router after controller action invocation.

Relevant units:

```text
Http/Http.Core.pas
Http/Attributes/Http.Attributes.pas
Http/Routing/Http.Router.pas
```

## TResponse

`TResponse` contains:

```pascal
StatusCode: Integer;
ContentType: string;
Body: string;
```

Factory helpers:

```pascal
TResponse.Json(const ABody: string; const AStatusCode: Integer = 200)
TResponse.NoContent
```

## Return values

A route action can return:

### TResponse

```pascal
function Download: TResponse;
```

### DTO object implementing IDto

```pascal
function Profile: TUserProfileDto;
```

The router serializes DTO objects to JSON.

### No content

If the action result is empty or nil, the router returns:

```pascal
204 No Content
```

## StatusCodeAttribute

Use `[StatusCode]` to override the response status code:

```pascal
[Post]
[StatusCode(201)]
function Create([FromBody] const Request: TCreateUserDto): TUserDto;
```

The router reads `StatusCodeAttribute` from the action method and applies it to the final response.

## Invalid return types

If an action returns an unsupported type, the router raises an exception.

Supported values are:

- `TResponse`;
- object implementing `IDto`;
- empty/nil.
