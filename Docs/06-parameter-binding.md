# Parameter Binding

Parameter binding maps request data to controller action parameters.

Relevant units:

```text
Http/Parameters/Http.Parameter.Attributes.pas
Http/Parameters/Http.Parameter.Binding.pas
Http/Parameters/Http.ParameterDescriptor.pas
Http/Parameters/Http.ActionMetadata.pas
Http/Parameters/Http.ParameterBinder.pas
```

## Binding sources

Parameters should declare where their values come from.

Common sources include:

- route parameters;
- query string;
- headers;
- body;
- HTTP context.

Example:

```pascal
[Get('/:id')]
function GetById([FromRoute] const Id: Integer): TUserDto;
```

Body example:

```pascal
[Post]
function Create([FromBody] const Request: TCreateUserDto): TUserDto;
```

## Metadata generation

`TActionMetadataFactory` reads RTTI from controller action parameters and creates `TParameterDescriptor` values.

Route descriptors keep parameter descriptors so binding is efficient at request time.

## Runtime binding

At request time:

1. `TActionInvoker` asks `TParameterBinder` to bind each parameter.
2. `TParameterBinder` reads the parameter descriptor.
3. It extracts the value from route/query/header/body/context.
4. It converts the value to the required Delphi type.

## Unsupported parameters

If a parameter cannot be bound or converted, the framework raises an exception instead of invoking the controller action with invalid values.
