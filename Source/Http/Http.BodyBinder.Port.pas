unit Http.BodyBinder.Port;

interface

uses
  System.Rtti;

type
  IBodyBinder = interface
    ['{5500405b-9f0a-4117-ac03-3e4fcfdf2729}']

    function Execute(const ARawBody: string; const ATargetType: TRttiType): TObject;
  end;

implementation

end.
