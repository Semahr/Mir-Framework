unit Http.EndpointAttributeHandler.Port;

interface

uses
  System.SysUtils,
  Http.Context,
  Http.Core,
  Http.Middleware.Port;

type
  IEndpointAttributeHandler = interface
    ['{655a3e84-5a45-4c8a-81dd-b5ea76069785}']
    function Supports(const AAttribute: TCustomAttribute): Boolean;

    function Invoke(
      const AAttribute: TCustomAttribute;
      const AContext: TContext;
      const ANext: TNextDelegate
    ): TResponse;
  end;

implementation

end.
