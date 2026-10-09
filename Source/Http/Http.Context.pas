unit Http.Context;

interface

uses
  System.SysUtils,
  Container.Scope,
  Http.Core;

type
  TContext = class
  private
    FRequest: TRequest;
    FDependencies: TContainerScope;
    FActionAttributes: TArray<TCustomAttribute>;
    FControllerAttributes: TArray<TCustomAttribute>;
  public
    constructor Create(
      const ARequest: TRequest;
      const ADependencies: TContainerScope;
      const AActionAttributes: TArray<TCustomAttribute> = nil;
      const AControllerAttributes: TArray<TCustomAttribute> = nil
    );

    /// <summary>
    /// Finds the first matching action attribute, then falls back to the controller.
    /// Includes descendant attribute types. The returned RTTI attribute must not be freed.
    /// </summary>
    function TryGetAttribute<T: TCustomAttribute>(out AAttribute: T): Boolean;

    property Request: TRequest read FRequest;
    property Dependencies: TContainerScope read FDependencies;
  end;

implementation

constructor TContext.Create(
  const ARequest: TRequest;
  const ADependencies: TContainerScope;
  const AActionAttributes: TArray<TCustomAttribute>;
  const AControllerAttributes: TArray<TCustomAttribute>
);
begin
  inherited Create;
  FRequest := ARequest;
  FDependencies := ADependencies;
  FActionAttributes := AActionAttributes;
  FControllerAttributes := AControllerAttributes;
end;

function TContext.TryGetAttribute<T>(out AAttribute: T): Boolean;
begin
  AAttribute := nil;

  for var Attribute in FActionAttributes do
    if Attribute is T then
    begin
      AAttribute := T(Attribute);
      Exit(True);
    end;

  for var Attribute in FControllerAttributes do
    if Attribute is T then
    begin
      AAttribute := T(Attribute);
      Exit(True);
    end;

  Result := False;
end;

end.
