unit Http.Middleware.Port;

interface

uses
  Http.Context,
  Http.Core;

type
  TNextDelegate = reference to function: TResponse;

  IMiddleware = interface
    ['{ad68f249-8b2f-49e5-b765-a76be0af9772}']
    function Invoke(const AContext: TContext; const ANext: TNextDelegate): TResponse;
  end;

implementation

end.
