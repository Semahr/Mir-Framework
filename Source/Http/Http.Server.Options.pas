unit Http.Server.Options;

interface

uses
  Options.Port;

type
  THttpServerOptions = class(TOptionsSection)
  private
    FPort: Integer;

    function GetSectionName: string; override;
  public
    property SectionName: string read GetSectionName;

    property Port: Integer read FPort write FPort;
  end;

implementation

function THttpServerOptions.GetSectionName: string;
begin
  Result := 'HttpServer';
end;

end.
