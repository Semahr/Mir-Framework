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

## Error responses

`TDefaultErrorResponseRenderer` in `Http.ErrorResponse` is a stateless utility:

```pascal
Response := TDefaultErrorResponseRenderer.Render(Error);
```

No renderer instance is required. Each call creates a new `TResponse`; the caller
owns it. When used by `THttpServer`, the server frees the response after writing it.
The exception remains owned by its original exception-handling scope.

Applications can still provide an `IErrorResponseRenderer` through the optional
`AErrorRenderer` argument of `THttpServer.Create` or
`THttpComposition.CreateDefaultServer`. The server uses the static default when
no custom renderer is supplied, or when the custom renderer raises an exception
or returns `nil`. The fallback renders the original request exception.

Compatibility: the default class no longer implements `IErrorResponseRenderer`.
Replace explicit default-renderer instance registrations with the omitted/nil
argument, or call its static `Render` method directly. Custom implementations of
`IErrorResponseRenderer` do not need to change.

### Environment and error details

Configure the environment in `TApplicationOptions` (unit `Application.Options`),
not in the HTTP server options. `App.Options` retains the root JSON alias
`TAppOptions`; the typed application section is separate:

```json
{
  "Application": {
    "Environment": "development"
  },
  "HttpServer": {
    "Port": 9090
  }
}
```

Only `SameText(Environment.Trim, 'development')` enables development behavior:
case is ignored and surrounding whitespace is trimmed (for example,
`" Development "` matches). This exposes the
original exception message for HTTP status **500**. `production`, `beta`, an
omitted/empty value, and any unrecognized value use the existing generic 500
messages. `develop` is not an alias for `development`. An omitted `Environment` means
an existing `Application` object without that property; omitting the whole
`Application` section fails options loading because the container registers it.

Explicit `EHttpException` responses with status 500 are also sanitized outside
development, including their error title. Other status codes retain their
original messages, including 502 and 503; do not put secrets in those messages.
The existing exception-to-status mappings are unchanged.

Composition passes `Application.Environment` from options to the server. Direct calls can
specify it explicitly, without shared global state:

```pascal
Response := TDefaultErrorResponseRenderer.Render(Error, 'development');
```

Omitting the second argument uses production behavior. Custom renderers still
control their own output; this policy applies to the default renderer and its
fallback, not to successful custom renderer responses. If a custom renderer
raises or returns `nil`, the fallback renders the original request exception
using the same server environment, including development behavior.

## Invalid return types

If an action returns an unsupported type, the router raises an exception.

Supported values are:

- `TResponse`;
- object implementing `IDto`;
- empty/nil.
