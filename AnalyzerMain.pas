unit AnalyzerMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  LazUTF8;

type
  TSCReg = (scClocking, scMapMask, scCharMap, scMemMode);
  TSCRegs = packed array[TSCReg] of Byte;
  TCRReg = (crHTotal, crHDispEnd, crHBlankStart, crHBlankEnd, crHSyncStart,
    crHSyncEnd, crVTotal, crOverflow, crPresetRow, crMaxScanLine, crCurStart,
    crCurEnd, crStartHigh, crStartLow, crCurLocHigh, crCurLocLow, crVSyncStart,
    crVSyncEnd, crVDispEnd, crOffset, crUnderline, crVBlankStart, crVBlankEnd,
    crModeControl, crLineCompare);
  TCRRegs = packed array[TCRReg] of Byte;
  TACReg = (acPal00, acPal01, acPal02, acPal03, acPal04, acPal05, acPal06,
    acPal07, acPal08, acPal09, acPal10, acPal11, acPal12, acPal13, acPal14,
    acPal15, acModeControl, acOverscan, acPlaneEnable, acHPan);
  TACRegs = packed array[TACReg] of Byte;
  TGCReg = (gcSetReset, gcEnableSR, gcCompare, gcRotate, gcReadMap,
    gcModeControl, gcMisc, gcDontCare, gcBitMask);
  TGCRegs = packed array[TGCReg] of Byte;
  TEGAData = packed record
    Cols, Rows:Byte;
    CharHeight:Byte;
    BufferSize:Word;
    SCRegs:TSCRegs;
    MOR:Byte;
    CRRegs:TCRRegs;
    ACRegs:TACRegs;
    GCRegs:TGCRegs;
  end;
  PEGAData = ^TEGAData;
  TBinData = array of Byte;
  TFreqData = array[0..3] of Integer;

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Edit1: TEdit;
    Memo1: TMemo;
    OpenDialog1: TOpenDialog;
    Panel1: TPanel;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FTabNumber:Integer;
  public
    procedure Push;
    procedure Pop;
    procedure ResetTabs;
    procedure Print(const AMsg:String);
    procedure PrintError(const AMsg:String);
    procedure PrintPalette(const AEGAData:TEGAData);
    procedure PrintData(const AEGAData:TEGAData;const AFreqData:TFreqData);
    procedure DebugPrint(ABinData:TBinData);
  end;

var
  Form1: TForm1;

const
  Version = 'v0.2';
  CpuID ={$ifdef CPUX86}'Win32'{$else}'Win64'{$endif};
  ReleaseID ={$ifdef DEBUG}'Debug'{$else}'Release'{$endif};
  TabWidth = 8;
  Bit0 = $01;
  Bit1 = $02;
  Bit2 = $04;
  Bit3 = $08;
  Bit4 = $10;
  Bit5 = $20;
  Bit6 = $40;
  Bit7 = $80;
  OpToStr:array[0..3] of String = ('None', 'AND', 'OR', 'XOR');
  WriteToStr:array[0..3] of String = (
    'Set/Reset', 'Mem->Mem', 'CPU->Mem', 'Invalid'
  );
  MapToStr:array[0..3] of String = (
    '0xA000 - 128Kb', '0xA000 - 64Kb', '0xB000 - 32Kb', '0xB800 - 32Kb'
  );

implementation

{$R *.lfm}

{ TForm1 }

function LoadText(const AFileName:String):TBinData;
  var Len, Curr, I:Integer;Input, S, Temp:String;
    Stream:TStrings;
begin
  Result := [];
  Stream := TStringList.Create;
  try
    Stream.LoadFromFile(AFileName);
    Input := Stream.Text;
    Len := Length(Input);
    Curr := 0;
    Temp := '$';
    while Curr < Len do begin
      S := Input[Curr + 1];
      if S = ' ' then begin
        if (Length(Temp) > 1) and TryStrToInt(Temp, I) and (I <= 255) then begin
          SetLength(Result, Length(Result) + 1);
          Result[Length(Result) - 1] := I;
          Temp := '$';
        end;
      end
      else begin
        Temp := Temp + S;
      end;
      Inc(Curr);
    end;
    if Length(Temp) > 1 then begin
      if (Length(Temp) > 1) and TryStrToInt(Temp, I) and (I <= 255) then begin
        SetLength(Result, Length(Result) + 1);
        Result[Length(Result) - 1] := I;
      end;
    end;
  finally
    Stream.Free;
  end;
end;

function LoadBin(const AFileName:String;AStart, AEnd:Int64):TBinData;
  var Stream:TStream;Curr:Longint;Len:Int64;Pos:SizeInt;
begin
  Result := [];
  if AEnd > AStart then begin
    Len := AEnd - AStart;
    SetLength(Result, Len);
    try
      Stream := TFileStream.Create(AFileName, fmOpenRead);
      Stream.Position := AStart;
      Pos := 0;
      while Len > 0 do begin
        if Len < MaxLongInt then begin
          Curr := Len;
        end
        else begin
          Curr := MaxLongInt;
        end;
        if Stream.Read(Result[Pos], Curr) <> Curr then begin
          Abort;
        end;
        Inc(Pos, Curr);
        Dec(Len, Curr);
      end;
    finally
      Stream.Free;
    end;
  end
  else begin
    Abort;
  end;
end;

function ByteToHex(const AByte:Byte):String;
begin
  Result := IntToStr(AByte) + ' (0x' + IntToHex(AByte, 2) + ')';
end;

function ByteToDots(const AByte:Byte; ADots:Integer):String;
begin
  Result := IntToStr(AByte) + ' (0x' + IntToHex(AByte, 2) +
    ', ' + IntToStr(AByte * ADots) + ')';
end;

function WordToHex(const AWord:Word):String;
begin
  Result := IntToStr(AWord) + ' (0x' + IntToHex(AWord, 4) + ')';
end;

function DWordToHex(const ADWord:Longword):String;
begin
  Result := IntToStr(ADWord) + ' (0x' + IntToHex(ADWord, 8) + ')';
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Caption := Caption + ' ' + Version + ' (' + CpuID + ' ' + ReleaseID + ')';
end;

procedure TForm1.Push;
begin
  FTabNumber += TabWidth;
end;

procedure TForm1.Pop;
begin
  if FTabNumber >= TabWidth then begin
    FTabNumber -= TabWidth;
  end;
end;

procedure TForm1.ResetTabs;
begin
  FTabNumber := 0;
end;

procedure TForm1.Print(const AMsg:String);
begin
  Memo1.Lines.Add(UTF8StringOfChar(' ', FTabNumber) + AMsg);
end;

procedure TForm1.PrintError(const AMsg:String);
begin
  Memo1.Lines.Add('Error: ' + AMsg);
end;

function CheckFlag(AFlag:Byte; AValue:Byte):Boolean;
begin
  Result := (AFlag and AValue) = AValue;
end;

function Choose(AFlag:Boolean;AChoice1:String;AChoice2:String):String;
begin
  if AFlag then begin
    Result := AChoice1;
  end
  else begin
    Result := AChoice2;
  end;
end;

function ChooseByte(AFlag:Boolean;AChoice1:Byte;AChoice2:Byte):Byte;
begin
  if AFlag then begin
    Result := AChoice1;
  end
  else begin
    Result := AChoice2;
  end;
end;

function PalToStr(constref AByte:Byte; ACount:Integer):String;
  var Addr:PByte;I:Integer;
begin
  Addr := @AByte;
  Result := '';
  for I := 0 to ACount - 1 do begin
   if I > 0 then begin
     Result += ' ';
   end;
   Result += ByteToHex(Addr^);
   Inc(Addr);
  end;
end;

procedure TForm1.PrintPalette(const AEGAData:TEGAData);
begin
  Print(PalToStr(AEGAData.ACRegs[acPal00], 4));
  Print(PalToStr(AEGAData.ACRegs[acPal04], 4));
  Print(PalToStr(AEGAData.ACRegs[acPal08], 4));
  Print(PalToStr(AEGAData.ACRegs[acPal12], 4));
end;

procedure TForm1.PrintData(const AEGAData:TEGAData;const AFreqData:TFreqData);
  var Temp, Dots, Shift, DotClock, HTotal, HFreq, HDisp, HBlankStart:Integer;
    HBlankEnd, DispStart, DESkew, HSyncStart, HSyncEnd, HSyncSkew:Integer;
    BytePan, VTotal, VSyncStart, VSyncEnd, VBlankStart, VBlankEnd:Integer;
    TextMode1, TextMode2, TextMode3, Agree1, Agree2, WordMode:Boolean;
    OddEven1, OddEven2:Boolean;
begin
  Print('General:');
  Push;
  Print('Width: ' + ByteToHex(AEGAData.Cols));
  Print('Height: ' + ByteToHex(AEGAData.Rows + 1));
  Print('Char height: ' + ByteToHex(AEGAData.CharHeight));
  Print('Buffer size: ' + WordToHex(AEGAData.BufferSize));
  Pop;
  Print('Sequencer:');
  Push;
  Print('Clocking mode:');
  Push;
  Dots := ChooseByte(CheckFlag(AEGAData.SCRegs[scClocking], Bit0), 8 , 9);
  Print(IntToStr(Dots) + '-dot mode');
  Print(Choose(CheckFlag(AEGAData.SCRegs[scClocking], Bit1), '2 of 5 bandwidth', '4 of 5 bandwidth'));
  Print(Choose(CheckFlag(AEGAData.SCRegs[scClocking], Bit2), 'Shift2 mode', 'Normal mode'));
  Print(Choose(CheckFlag(AEGAData.SCRegs[scClocking], Bit3), '1/2 dot clock', 'Normal dot clock'));
  Shift := ChooseByte(CheckFlag(AEGAData.SCRegs[scClocking], Bit3), 1, 0);
  Pop;
  Print('Map mask: ' + ByteToHex(AEGAData.SCRegs[scMapMask]));
  Print('Character map:');
  Push;
  Print('Map A: ' + ByteToHex((AEGAData.SCRegs[scCharMap] and $0C) shr 2));
  Print('Map B: ' + ByteToHex(AEGAData.SCRegs[scCharMap] and $03));
  Pop;
  Print('Memory mode:');
  Push;
  TextMode1 := CheckFlag(AEGAData.SCRegs[scMemMode], Bit0);
  TextMode2 := not CheckFlag(AEGAData.ACRegs[acModeControl], Bit0);
  TextMode3 := not CheckFlag(AEGAData.GCRegs[gcMisc], Bit0);
  Agree1 := (TextMode1 = TextMode2) and (TextMode2 = TextMode3);
  Print(Choose(TextMode1, 'Text mode', 'Graphic mode') + ' (' +
    Choose(Agree1, 'SC/AC/GC modes aggree', 'SC/AC/GC modes disagree') + ')');
  Print(Choose(CheckFlag(AEGAData.SCRegs[scMemMode], Bit1), 'Memory expansion', 'No memory expansion'));
  OddEven1 := not CheckFlag(AEGAData.SCRegs[scMemMode], Bit2);
  OddEven2 := CheckFlag(AEGAData.GCRegs[gcModeControl], Bit4);
  Agree2 := OddEven1 = OddEven2;
  Print(Choose(OddEven2, 'Odd/Even mode', 'Planar mode') + ' (' +
    Choose(Agree2, 'SC/GC modes aggree', 'SC/GC modes disagree') + ')');
  Pop;
  Pop;
  Print('MOR:');
  Push;
  Print(Choose(CheckFlag(AEGAData.MOR, Bit0), 'Color CRTC 3Dx', 'Mono CRTC 3Bx'));
  Print(Choose(CheckFlag(AEGAData.MOR, Bit1), 'VRAM enabled', 'VRAM disabled'));
  Temp := (AEGAData.MOR and $0C) shr 2;
  Print('Clock select: ' + ByteToHex(Temp));
  DotClock := AFreqData[Temp] shr Shift;
  Print('Estimated dot clock: ' + IntToStr(DotClock) + 'Hz');
  Print(Choose(CheckFlag(AEGAData.MOR, Bit4), 'External drivers', 'Internal drivers'));
  Print(Choose(CheckFlag(AEGAData.MOR, Bit5), 'High Odd/Even page', 'Low Odd/Even page'));
  Print(Choose(CheckFlag(AEGAData.MOR, Bit6), 'Horizontal retrace negative', 'Horizontal retrace positive'));
  Print(Choose(CheckFlag(AEGAData.MOR, Bit7), 'Vertical retrace negative', 'Vertical retrace positive'));
  Pop;
  Print('CRTC:');
  Push;
  Print('Horizontal values as is:');
  Push;
  HTotal := AEGAData.CRRegs[crHTotal];
  Print('Horizotal total: ' + ByteToDots(HTotal, Dots));
  HDisp := AEGAData.CRRegs[crHDispEnd];
  Print('Horizontal displayed: ' + ByteToDots(HDisp, Dots));
  HBlankStart := AEGAData.CRRegs[crHBlankStart];
  Print('Horizontal blanking start: ' + ByteToDots(HBlankStart, Dots));
  if HBlankStart > HTotal + 1 then begin
    Print('Horizontal blanking start beyond total');
  end;
  HBlankEnd := (AEGAData.CRRegs[crHBlankStart] and $E0) or
    (AEGAData.CRRegs[crHBlankEnd] and $1F);
  if HBlankEnd < HBlankStart then begin
    HBlankEnd := ((AEGAData.CRRegs[crHBlankStart] + $1F) and $E0) or
      (AEGAData.CRRegs[crHBlankEnd] and $1F);
  end;
  Print('Horizontal blanking end: ' + ByteToDots(HBlankEnd, Dots));
  if HBlankEnd > HTotal + 1 then begin
    HBlankEnd := HTotal + 1;
    Print('Horizontal blanking end real value: ' + ByteToDots(HBlankEnd, Dots));
  end;
  Print('Horizontal blanking width: ' + ByteToDots(Byte(HBlankEnd - HBlankStart), Dots));
  DESkew := (AEGAData.CRRegs[crHBlankEnd] and $60) shr 5;
  Print('Display enable skew: ' + ByteToDots(DESkew, Dots));
  HSyncStart := AEGAData.CRRegs[crHSyncStart];
  Print('Horizontal sync start: ' + ByteToDots(HSyncStart, Dots));
  if HSyncStart > HTotal + 1 then begin
    Print('Horizontal sync start beyond total');
  end;
  HSyncEnd := (HSyncStart and $E0) or (AEGAData.CRRegs[crHSyncEnd] and $1F);
  if HSyncEnd < HSyncStart then begin
    HSyncEnd := ((HSyncStart + $1F) and $E0) or (AEGAData.CRRegs[crHSyncEnd] and $1F);
  end;
  Print('Horizontal sync end: ' + ByteToDots(HSyncEnd, Dots));
  if HSyncEnd > HTotal + 1 then begin
    HSyncEnd := HTotal + 1;
    Print('Horizontal sync end real value: ' + ByteToDots(HSyncEnd, Dots));
  end;
  Print('Horizontal sync width: ' + ByteToDots(Byte(HSyncEnd - HSyncStart), Dots));
  HSyncSkew := (AEGAData.CRRegs[crHSyncEnd] and $60) shr 5;
  Print('Horizontal sync skew: ' + ByteToDots(HSyncSkew, Dots));
  BytePan := (AEGAData.CRRegs[crHSyncEnd] and $80) shr 7;
  Print('Byte panning: ' + ByteToDots(BytePan, Dots));
  Pop;
  Print('Adjusted horizontal values:');
  Push;
  Print('Horizotal total: ' + ByteToDots(HTotal + 2, Dots));
  HFreq := DotClock div ((HTotal + 2) * Dots);
  Print('Estimated horizontal frequency: ' + IntToStr(HFreq) + 'Hz');
  Print('Horizontal displayed: ' + ByteToDots(HDisp + 1, Dots));
  if TextMode2 then begin
    DispStart := 4;
  end
  else begin
    DispStart := 3;
  end;
  Print('Horizontal display start: ' + ByteToDots(DispStart, Dots));
  Print('Horizontal display end: ' + ByteToDots(DispStart + HDisp, Dots));
  Print('Horizontal blanking start: ' + ByteToDots(HBlankStart + 1, Dots));
  if HBlankStart > HTotal + 1 then begin
    Print('Horizontal blanking start beyond total');
  end;
  Print('Horizontal blanking end: ' + ByteToDots(HBlankEnd + 1, Dots));
  Print('Horizontal blanking width: ' + ByteToDots(Byte(HBlankEnd - HBlankStart), Dots));
  Print('Display enable skew: ' + ByteToDots(DESkew, Dots));
  Print('Horizontal sync start: ' + ByteToDots(HSyncStart + HSyncSkew, Dots));
  if HSyncStart > HTotal + 1 then begin
    Print('Horizontal sync start beyond total');
  end;
  Print('Horizontal sync end: ' + ByteToDots(HSyncEnd + HSyncSkew, Dots));
  Print('Horizontal sync width: ' + ByteToDots(Byte(HSyncEnd - HSyncStart), Dots));
  Print('Horizontal sync skew: ' + ByteToDots(HSyncSkew, Dots));
  Print('Byte panning: ' + ByteToDots(BytePan, Dots));
  Pop;
  Print('Vertical and other values:');
  Push;
  VTotal := AEGAData.CRRegs[crVTotal] + (AEGAData.CRRegs[crOverflow] and 1) shl 8;
  Print('Vertical total: ' + WordToHex(VTotal));
  Temp := (HFreq * 100) div VTotal;
  Print('Estimated vertical frequency: ' + IntToStr(Temp div 100) + '.' + IntToStr(Temp mod 100));
  Print('Preset row: ' + ByteToHex(AEGAData.CRRegs[crPresetRow] and $1F));
  Print('Max scan line: ' + ByteToHex(AEGAData.CRRegs[crMaxScanLine] and $1F));
  Print('Cursor start: ' + ByteToHex(AEGAData.CRRegs[crCurStart] and $1F));
  Print('Cursor end: ' + ByteToHex(AEGAData.CRRegs[crCurEnd] and $1F));
  Print('Cursor skew: ' + ByteToHex((AEGAData.CRRegs[crCurEnd] and $60) shr 5));
  Temp := AEGAData.CRRegs[crStartLow] + (AEGAData.CRRegs[crStartHigh] shl 8);
  Print('Start address: ' + WordToHex(Temp));
  Temp := AEGAData.CRRegs[crCurLocLow] + (AEGAData.CRRegs[crCurLocHigh] shl 8);
  Print('Cursor location: ' + WordToHex(Temp));
  VSyncStart := AEGAData.CRRegs[crVSyncStart] + ((AEGAData.CRRegs[crOverflow] and Bit2) shl 6);
  Print('Vertical sync start: ' + WordToHex(VSyncStart));
  if VSyncStart > VTotal - 1 then begin
    Print('Vertical sync start beyond total');
  end;
  VSyncEnd := (VSyncStart and $1F0) or (AEGAData.CRRegs[crVSyncEnd] and $0F);
  if VSyncEnd < VSyncStart then begin
    VSyncEnd := ((VSyncStart + $0F) and $1F0) or (AEGAData.CRRegs[crVSyncEnd] and $0F);
  end;
  Print('Vertical sync end: ' + WordToHex(VSyncEnd));
  if VSyncEnd > VTotal - 1 then begin
    VSyncEnd := VTotal - 1;
    Print('Vertical sync end real value: ' + WordToHex(VSyncEnd));
  end;
  if VSyncEnd >= VSyncStart then begin
    Print('Vertical sync width: ' + WordToHex(VSyncEnd - VSyncStart));
  end;
  Print(Choose(CheckFlag(AEGAData.CRRegs[crVSyncEnd], Bit4), 'No vertical interrupt clear',
    'Clear vertical interrupt'));
  Print(Choose(CheckFlag(AEGAData.CRRegs[crVSyncEnd], Bit5), 'Vertical interrupt disabled',
    'Vertical interrupt enabled'));
  Temp := AEGAData.CRRegs[crVDispEnd] or ((AEGAData.CRRegs[crOverflow] and Bit1) shl 7);
  Print('Vertical display end: ' + WordToHex(Temp));
  Print('Vertical display height: ' + WordToHex(Temp + 1));
  WordMode := CheckFlag(AEGAData.CRRegs[crModeControl], Bit6);
  Temp := AEGAData.CRRegs[crOffset];
  Print('Offset: ' + ByteToDots(Temp, Dots));
  Temp := Temp shl 1;
  if WordMode then begin
    Temp := Temp shl 1;
  end;
  Print('Adjusted offset: ' + ByteToDots(Temp, Dots));
  Print('Underline location: ' + ByteToHex(AEGAData.CRRegs[crUnderline] and $1F));
  VBlankStart := AEGAData.CRRegs[crVBlankStart] or ((AEGAData.CRRegs[crOverflow] and Bit3) shl 4);
  Print('Vertical blanking start: ' + WordToHex(VBlankStart));
  if VBlankStart > VTotal - 1 then begin
    Print('Vertical blanking start beyond total');
  end;
  VBlankEnd := (VBlankStart and $E0) or (AEGAData.CRRegs[crVBlankEnd] and $1F);
  if VBlankEnd < VBlankStart then begin
    VBlankEnd := ((VBlankStart + $1F) and $E0) or (AEGAData.CRRegs[crVBlankEnd] and $1F);
  end;
  Print('Vertical blanking end: ' + WordToHex(VBlankEnd));
  if VBlankEnd > VTotal - 1 then begin
    VBlankEnd := VTotal - 1;
    Print('Vertical blanking end real value: ' + WordToHex(VBlankEnd));
  end;
  if VBlankEnd >= VBlankStart then begin
    Print('Vertical blank width: ' + WordToHex(VBlankEnd - VBlankStart));
  end;
  Print('Mode control:');
  Push;
  Print(Choose(CheckFlag(AEGAData.CRRegs[crModeControl], Bit0), 'MA13 = A13', 'MA13 = RS0'));
  Print(Choose(CheckFlag(AEGAData.CRRegs[crModeControl], Bit1), 'MA14 = A14', 'MA14 = RS1'));
  Print(Choose(CheckFlag(AEGAData.CRRegs[crModeControl], Bit2), 'Vertical counter doubled', 'Vertical counter normal'));
  Print(Choose(CheckFlag(AEGAData.CRRegs[crModeControl], Bit3), 'Address clocked by CCLK/2', 'Address clocked by CCLK'));
  Print(Choose(CheckFlag(AEGAData.CRRegs[crModeControl], Bit4), 'Outputs disabled', 'Outputs enabled'));
  Print(Choose(CheckFlag(AEGAData.CRRegs[crModeControl], Bit5), 'MA0 = MA15 in Word mode', 'MA0 = MA13 in Word mode'));
  Print(Choose(CheckFlag(AEGAData.CRRegs[crModeControl], Bit6), 'Byte mode', 'Word mode'));
  Print(Choose(CheckFlag(AEGAData.CRRegs[crModeControl], Bit7), 'Syncs enabled', 'Syncs disabled'));
  Pop;
  Print('Line compare: ' + ByteToHex(AEGAData.CRRegs[crLineCompare]));
  Pop;
  Print('Attribute controller:');
  Push;
  Print('Palette:');
  Push;
  PrintPalette(AEGAData);
  Pop;
  Print('Mode control:');
  Push;
  Print(Choose(TextMode2, 'Text mode', 'Graphic mode') + ' (' +
    Choose(Agree1, 'SC/AC/GC modes aggree', 'SC/AC/GC modes disagree') + ')');    Print(Choose(CheckFlag(AEGAData.ACRegs[acModeControl], Bit1), 'Mono mode', 'Color mode'));
  Print(Choose(CheckFlag(AEGAData.ACRegs[acModeControl], Bit2), 'Line graphics enabled', 'Line graphics disabled'));
  Print(Choose(CheckFlag(AEGAData.ACRegs[acModeControl], Bit3), 'Blink enabled', 'Blink disabled'));
  Pop;
  Print('Overscan color: ' + ByteToHex(AEGAData.ACRegs[acOverscan]));
  Print('Plane enable: ' + ByteToHex(AEGAData.ACRegs[acPlaneEnable] and $0F));
  Print('Video status: ' + ByteToHex((AEGAData.ACRegs[acPlaneEnable] and $30) shr 4));
  Print('Horizontal panning: ' + ByteToHex(AEGAData.ACRegs[acHPan] and $0F));
  Pop;
  Print('Graphics controller:');
  Push;
  Print('Set/Reset: ' + ByteToHex(AEGAData.GCRegs[gcSetReset] and $0F));
  Print('Enable Set/Reset: ' + ByteToHex(AEGAData.GCRegs[gcEnableSR] and $0F));
  Print('Color compare: ' + ByteToHex(AEGAData.GCRegs[gcCompare] and $0F));
  Print('Data mode:');
  Push;
  Print('Data rotate: ' + ByteToHex(AEGAData.GCRegs[gcRotate] and $07));
  Print('Data operation: ' + OpToStr[(AEGAData.GCRegs[gcRotate] and $18) shr 3]);
  Pop;
  Print('Read map: ' + ByteToHex(AEGAData.GCRegs[gcReadMap] and $07));
  Print('Mode control:');
  Push;
  Print('Write mode: ' + WriteToStr[AEGAData.GCRegs[gcModeControl] and $03]);
  Print('Test condition: ' + Choose(CheckFlag(AEGAData.GCRegs[gcModeControl], Bit2), 'True', 'False'));
  Print('Read mode: ' + Choose(CheckFlag(AEGAData.GCRegs[gcModeControl], Bit3), 'Compare', 'Read'));
  Print(Choose(OddEven2, 'Odd/Even mode', 'Planar mode') + ' (' +
    Choose(Agree2, 'SC/GC modes aggree', 'SC/GC modes disagree') + ')');
  Print(Choose(CheckFlag(AEGAData.GCRegs[gcModeControl], Bit5), 'Chain2 mode', 'Normal mode'));
  Pop;
  Print('Miscellaneous:');
  Push;
  Print(Choose(TextMode3, 'Text mode', 'Graphic mode') + ' (' +
    Choose(Agree1, 'SC/AC/GC modes aggree', 'SC/AC/GC modes disagree') + ')');
  Print(Choose(CheckFlag(AEGAData.GCRegs[gcMisc], Bit1), 'CPU MA0 = PGSEL/A14/A16 (ChainOE)', 'CPU MA0 = A0 (Normal)'));
  Print('Memory map: ' + MapToStr[(AEGAData.GCRegs[gcMisc] and $0C) shr 2]);
  Pop;
  Print('Color don''t care: ' + ByteToHex(AEGAData.GCRegs[gcDontCare] and $0F));
  Print('Bit mask: ' + ByteToHex(AEGAData.GCRegs[gcBitMask]));
  Pop;
end;

procedure TForm1.DebugPrint(ABinData:TBinData);
  var Temp:String;I:Integer;
begin
  Temp := '';
  for I := 0 to Length(ABinData) - 1 do begin
    if I > 0 then begin
      Temp += ' ';
    end;
    Temp += IntToHex(ABinData[I], 2);
  end;
  Print(Temp);
end;

procedure TForm1.Button1Click(Sender: TObject);
  var Config:TStrings;Cmd, ConfigPath, FilePath, Temp:String;
    BinData:TBinData;I, Count:Integer;DataStart, DataEnd:Int64;
    FreqData:TFreqData;EGAData:PEGAData;
begin
  Memo1.Clear;
  Config := TStringList.Create;
  try
    Config.LoadFromFile(Edit1.Text);
    ConfigPath := ExtractFilePath(Edit1.Text);
    if Config.Count >= 8 then begin
      Cmd := UpperCase(Trim(Config[0]));
      FilePath := Trim(Config[1]);
      Temp := Trim(Config[2]);
      if not TryStrToInt64(Temp, DataStart) then begin
        Print('Error reading data start value: ' + Temp);
        Abort;
      end;
      Temp := Trim(Config[3]);
      if not TryStrToInt64(Temp, DataEnd) then begin
        Print('Error reading data end value: ' + Temp);
        Abort;
      end;
      for I := 0 to 3 do begin
        Temp := Trim(Config[4 + I]);
        if not TryStrToInt(Temp, FreqData[I]) then begin
          Print('Error reading data frequency value: ' + Temp);
          Abort;
        end;
      end;
      try
        case Cmd of
          'BINABS':begin
            BinData := LoadBin(FilePath, DataStart, DataEnd);
          end;
          'BINREL':begin
            FilePath := ConcatPaths([ConfigPath, FilePath]);
            BinData := LoadBin(FilePath, DataStart, DataEnd);
          end;
          'TEXTABS':begin
              BinData := LoadText(FilePath);
          end;
          'TEXTREL':begin
            FilePath := ConcatPaths([ConfigPath, FilePath]);
            BinData := LoadText(FilePath);
          end;
          else begin
            PrintError('Unknown command: ' + Cmd);
          end;
        end;
        Count := Length(BinData) div SizeOf(TEGAData);
        EGAData := @BinData[0];
        for I := 0 to Count - 1 do begin
          Print(UTF8StringOfChar('-', 80));
          Print('Mode ' + DWordToHex(I));
          Push;
          PrintData(EGAData^, FreqData);
          ResetTabs;
          Inc(EGAData);
        end;
      except
        PrintError('Couldn''t read source file: ' + FilePath);
        Abort;
      end;
    end
    else begin
      PrintError('Wrong config size: ' + IntToStr(Config.Count));
      Abort;
    end;
  except
    Print('Fatal: process aborted');
  end;
  Config.Free;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  if OpenDialog1.Execute then begin
    Edit1.Text := OpenDialog1.FileName;
  end;
end;

end.

