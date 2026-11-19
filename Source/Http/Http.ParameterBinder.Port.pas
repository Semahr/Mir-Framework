unit Http.ParameterBinder.Port;

interface

uses
  System.Rtti,
  Http.Context,
  Http.ParameterDescriptor;

type
  IParameterBinder = interface
    ['{e7e55968-99c6-4702-8310-ef90b846f43d}']

    function Execute(const AContext: TContext; const ADescriptor: TParameterDescriptor): TValue;
  end;

implementation

end.
