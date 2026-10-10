unit App.Options;

interface

uses
  Options.Port,
  System.JSON;

type
  TAppOptions = TJSONObject;

  TApplicationOptions = class(TOptionsSection)
  private
    FEnvironment: string;

    function GetSectionName: string; override;
  public
    property SectionName: string read GetSectionName;

    property Environment: string read FEnvironment write FEnvironment;
  end;

implementation

{ TApplicationOptions }

function TApplicationOptions.GetSectionName: string;
begin
  Result := 'Application';
end;

end.
