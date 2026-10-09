unit Http.ErrorResponse.Port;

interface

uses
  System.SysUtils,
  Http.Core;

type
  IErrorResponseRenderer = interface
    ['{7A4A44A2-5C3C-4F35-9D0F-6D7F4D1A8B21}']
    function Render(const AError: Exception): TResponse;
  end;

implementation

end.
