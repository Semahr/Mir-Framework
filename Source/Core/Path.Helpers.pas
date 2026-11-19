unit Path.Helpers;

interface

uses
  System.SysUtils,
  AppExceptions;

{$SCOPEDENUMS ON}

type
  TPathKind = (
    FilePath,
    DirectoryPath
  );

  EPathValidationException = class(EInvalidDependencyException);

  TPathHelpers = class sealed
  private
    class function NormalizeSeparators(const Value: string): string; static;
    class function IsReservedWindowsName(const Segment: string): Boolean; static;
    class procedure ValidatePathSegment(const Segment: string; const AllowNavigationSegments: Boolean); static;
    class procedure ValidatePathSegments(const PathValue: string; const Kind: TPathKind); static;
    class procedure EnsureDirectory(const DirectoryPath: string); static;
  public
    class function ValidatePath(
      const PathValue: string;
      const Kind: TPathKind;
      const AllowRelativePath: Boolean = True;
      const MustExist: Boolean = False;
      const CreateDirectory: Boolean = False
    ): string; static;

    class function TryValidatePath(
      const PathValue: string;
      const Kind: TPathKind;
      const AllowRelativePath: Boolean = True;
      const MustExist: Boolean = False;
      const CreateDirectory: Boolean = False
    ): Boolean; static;

    class function CanBeOpen(const PathValue: string): Boolean;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.StrUtils;

class function TPathHelpers.NormalizeSeparators(const Value: string): string;
begin
  Result := Trim(Value);

  {$IFDEF MSWINDOWS}
  Result := Result.Replace('/', PathDelim);
  {$ENDIF}
end;

class function TPathHelpers.IsReservedWindowsName(const Segment: string): Boolean;
var
  NameWithoutExtension: string;
begin
  {$IFDEF MSWINDOWS}
  NameWithoutExtension := UpperCase(ChangeFileExt(Segment, ''));

  Result :=
    (NameWithoutExtension = 'CON') or
    (NameWithoutExtension = 'PRN') or
    (NameWithoutExtension = 'AUX') or
    (NameWithoutExtension = 'NUL') or
    StartsText('COM', NameWithoutExtension) and
      (Length(NameWithoutExtension) = 4) and
      CharInSet(NameWithoutExtension[4], ['1'..'9']) or
    StartsText('LPT', NameWithoutExtension) and
      (Length(NameWithoutExtension) = 4) and
      CharInSet(NameWithoutExtension[4], ['1'..'9']);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

class procedure TPathHelpers.ValidatePathSegment(
  const Segment: string;
  const AllowNavigationSegments: Boolean
);
begin
  if Segment.Trim.IsEmpty then
    raise EPathValidationException.Create('Path contains an empty segment.');

  if AllowNavigationSegments and ((Segment = '.') or (Segment = '..')) then
    Exit;

  if not TPath.HasValidFileNameChars(Segment, False) then
    raise EPathValidationException.CreateFmt(
      'Invalid path segment: "%s".',
      [Segment]
    );

  {$IFDEF MSWINDOWS}
  if Segment.EndsWith(' ') or Segment.EndsWith('.') then
    raise EPathValidationException.CreateFmt(
      'Path segment cannot end with space or dot: "%s".',
      [Segment]
    );

  if IsReservedWindowsName(Segment) then
    raise EPathValidationException.CreateFmt(
      'Path segment uses a reserved Windows name: "%s".',
      [Segment]
    );
  {$ENDIF}
end;

class procedure TPathHelpers.ValidatePathSegments(
  const PathValue: string;
  const Kind: TPathKind
);
var
  Drive: string;
  PathWithoutDrive: string;
  Segments: TArray<string>;
  Segment: string;
  NormalizedPath: string;
begin
  NormalizedPath := PathValue;

  {$IFDEF MSWINDOWS}
  Drive := ExtractFileDrive(NormalizedPath);
  PathWithoutDrive := NormalizedPath;

  if not Drive.IsEmpty then
    Delete(PathWithoutDrive, 1, Length(Drive));

  PathWithoutDrive := PathWithoutDrive.Trim([PathDelim]);

  if PathWithoutDrive.IsEmpty then
  begin
    if Kind = TPathKind.FilePath then
      raise EPathValidationException.CreateFmt(
        'Invalid file path: "%s". File name is missing.',
        [PathValue]
      );

    Exit;
  end;

  Segments := PathWithoutDrive.Split([PathDelim]);
  {$ELSE}
  PathWithoutDrive := NormalizedPath.Trim([PathDelim]);

  if PathWithoutDrive.IsEmpty then
  begin
    if Kind = TPathKind.FilePath then
      raise EPathValidationException.CreateFmt(
        'Invalid file path: "%s". File name is missing.',
        [PathValue]
      );

    Exit;
  end;

  Segments := PathWithoutDrive.Split([PathDelim]);
  {$ENDIF}

  for Segment in Segments do
    ValidatePathSegment(Segment, True);
end;

class procedure TPathHelpers.EnsureDirectory(const DirectoryPath: string);
begin
  if DirectoryPath.Trim.IsEmpty then
    Exit;

  try
    TDirectory.CreateDirectory(DirectoryPath);
  except
    on E: Exception do
      raise EPathValidationException.CreateFmt(
        'Cannot create directory "%s": %s',
        [DirectoryPath, E.Message]
      );
  end;
end;

class function TPathHelpers.ValidatePath(
  const PathValue: string;
  const Kind: TPathKind;
  const AllowRelativePath: Boolean;
  const MustExist: Boolean;
  const CreateDirectory: Boolean
): string;
var
  DirectoryPath: string;
  FileName: string;
begin
  if PathValue.Trim.IsEmpty then
    raise EPathValidationException.Create('Path cannot be empty.');

  Result := NormalizeSeparators(PathValue);

  if not TPath.HasValidPathChars(Result, False) then
    raise EPathValidationException.CreateFmt(
      'Invalid path: "%s".',
      [Result]
    );

  if not AllowRelativePath and not TPath.IsPathRooted(Result) then
    raise EPathValidationException.CreateFmt(
      'Path must be absolute: "%s".',
      [Result]
    );

  ValidatePathSegments(Result, Kind);

  case Kind of
    TPathKind.FilePath:
      begin
        FileName := ExtractFileName(Result);

        if FileName.Trim.IsEmpty then
          raise EPathValidationException.CreateFmt(
            'Invalid file path: "%s". File name is missing.',
            [Result]
          );

        ValidatePathSegment(FileName, False);

        DirectoryPath := ExtractFilePath(Result);

        if CreateDirectory and not DirectoryPath.Trim.IsEmpty then
          EnsureDirectory(DirectoryPath);

        if MustExist and not TFile.Exists(Result) then
          raise EPathValidationException.CreateFmt(
            'File does not exist: "%s".',
            [Result]
          );
      end;

    TPathKind.DirectoryPath:
      begin
        if CreateDirectory then
          EnsureDirectory(Result);

        if MustExist and not TDirectory.Exists(Result) then
          raise EPathValidationException.CreateFmt(
            'Directory does not exist: "%s".',
            [Result]
          );
      end;
  end;
end;

class function TPathHelpers.TryValidatePath(
  const PathValue: string;
  const Kind: TPathKind;
  const AllowRelativePath: Boolean;
  const MustExist: Boolean;
  const CreateDirectory: Boolean
): Boolean;
begin
  Result := False;

  try
    var ValidatedPath := ValidatePath(
      PathValue,
      Kind,
      AllowRelativePath,
      MustExist,
      CreateDirectory
    );

    Result := not ValidatedPath.IsEmpty;
  except
  end;
end;

class function TPathHelpers.CanBeOpen(const PathValue: string): Boolean;
var
  FileStream: TFileStream;
begin
  Result := False;

  try
    if FileExists(PathValue) then
      FileStream := TFileStream.Create(PathValue, fmOpenReadWrite or fmShareDenyNone)
    else
      FileStream := TFileStream.Create(PathValue, fmCreate or fmShareDenyNone);

    try
      FileStream.Seek(0, soEnd);
    finally
      FileStream.Free;
    end;

    Result := True;
  except
  end;
end;

end.
