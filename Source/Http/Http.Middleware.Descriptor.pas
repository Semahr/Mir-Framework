unit Http.Middleware.Descriptor;

interface

type
  TMiddlewareDescriptor = record
  private
    FMiddlewareType: TClass;
    FOrder: Integer;
  public
    constructor Create(const AMiddlewareType: TClass; const AOrder: Integer = 0);

    property MiddlewareType: TClass read FMiddlewareType;
    property Order: Integer read FOrder;
  end;

implementation

constructor TMiddlewareDescriptor.Create(const AMiddlewareType: TClass; const AOrder: Integer);
begin
  FMiddlewareType := AMiddlewareType;
  FOrder := AOrder;
end;

end.
