program Launcher;

uses SysUtils, Windows;

const
  Bin32:String = 'Bin32';
  Bin64:String = 'Bin64';
  FileName:String = 'EGAAnalyzer.exe';

type
  TIsWOW64Process = function(hProcess:THandle;var IsWOW64:Boolean):Boolean;stdcall;

function Is64Bit:Boolean;
  var Kernel:THandle;IsWOW64Process:TIsWOW64Process;Temp:Boolean;
begin
  Temp := False;
  Kernel := LoadLibrary('KERNEL32.DLL');
  if (Kernel <> 0) then begin
    IsWOW64Process := TIsWOW64Process(GetProcAddress(Kernel, 'IsWow64Process'));
    if Assigned(IsWOW64Process) then begin
      IsWow64Process(Kernel, Temp);
    end;
  end;
  FreeLibrary(Kernel);
  Result := not Temp;
end;

function GetName:String;
begin
  if Is64Bit then begin
    Result := Bin64;
  end
  else begin
    Result := Bin32;
  end;
  Result := ConcatPaths([ExtractFilePath(ParamStr(0)), Result, FileName]);
end;

function GetParams:String;
  var I:Integer;
begin
  Result := '';
  for I := 1 to ParamCount do begin
    if I > 1 then begin
      Result := Result + ' ';
    end;
    if Pos(' ', ParamStr(I)) > 0 then begin
      Result := Result + '"' + ParamStr(I) + '"';
    end
    else begin
      Result := Result + ParamStr(I);
    end;
  end;
end;

{$R *.res}

var Name, Params, Path:UnicodeString;

begin
  Name := UnicodeString(GetName);
  Params := UnicodeString(GetParams);
  Path := UnicodeString(ExtractFilePath(ParamStr(0)));
  ShellExecuteW(
    0,
    'open',
    PWideChar(Name),
    PWideChar(Params),
    PWideChar(Path),
    SW_SHOWNORMAL
  );
end.

