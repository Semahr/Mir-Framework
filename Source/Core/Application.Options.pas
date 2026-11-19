unit Application.Options;

interface

uses
  Options.Port;

type
  TApplicationOptions = class(TOptionsSection)
  private
    FEnvironment: string;

    function GetSectionName: string; override;
  public
    property Environment: string read FEnvironment write FEnvironment;
  end;

implementation

function TApplicationOptions.GetSectionName: string;
begin
  Result := 'Application';
end;

end.
