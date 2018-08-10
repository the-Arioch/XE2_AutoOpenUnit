// -------------------------------------------------------------------------
//
//                         Automatically open units
//                            By Yoav Abrahami
//
// This wizard automatically opens units when before a unit is opened.
// It is used to open units that are base units for inherited forms.
// The syntax is simply to add a comment in the file like
// { A utoOpenUnit someunitname}
//
// -------------------------------------------------------------------------

{$T+}
{$PointerMath ON}
{$WARN SYMBOL_PLATFORM OFF}

unit AutoOpenUnitWizard;

interface

Uses
  SysUtils, Classes, ToolsAPI,
//  menus, dialogs, consts, contnrs, registry, windows,
  Forms, // Application
  StrUtils;

Type
  TAutoOpenUnitExpert = class(TNotifierObject, IOTAWizard)
  Private
    OpenFileNotifier: IOTAIDENotifier;
    NotifierIndex: Integer;
  Public
    Constructor Create;
    Destructor Destroy; Override;
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  End;

Procedure Register;

implementation
uses IOUtils;

Procedure Register;
Begin
  RegisterPackageWizard(TAutoOpenUnitExpert.Create);
End;


function ScanFF(const Source, Search:String; const Start: Integer; const SkipTag: boolean):Integer;
Var
  p: PChar;
Begin
  if SkipTag
     then Result := Length( Search )
     else Result := 0;
  p := SearchBuf(PChar(Source), Length(Source), 0, Start-1, Search);
  if p = Nil
     then Result := 0 // regardless of Skip flag
     else Inc( Result, p-PChar(Source) + 1);
end;


function CurrentProjectGroup: IOTAProjectGroup;
var
  I: Integer;
  ModSvc: IOTAModuleServices;
begin
  ModSvc:=BorlandIDEServices as IOTAModuleServices;
  for I:=0 to ModSvc.ModuleCount-1 do
    if ModSvc.Modules[I].QueryInterface(IOTAProjectGroup,Result)=0 then
      Exit;
  Result:=nil;
end;

Type

  TOpenFileIDENotifier = Class(TInterfacedObject, IOTAIDENotifier)
  Private
    DPROJ_Opening, DPROJ_ProjSource: string;

    Function FindUnit(UnitName: string): string;
  Public
    procedure FileNotification(NotifyCode: TOTAFileNotification;
      const FileName: string; var Cancel: Boolean);
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean); overload;
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;
  End;


{ TAutoOpenUnitExpert }

constructor TAutoOpenUnitExpert.Create;
begin
  inherited;
  OpenFileNotifier := TOpenFileIDENotifier.Create;
  NotifierIndex := (BorlandIDEServices as IOTAServices).AddNotifier(OpenFileNotifier)
end;

destructor TAutoOpenUnitExpert.Destroy;
begin
  (BorlandIDEServices as IOTAServices).RemoveNotifier(NotifierIndex);
  inherited;
end;

procedure TAutoOpenUnitExpert.Execute;
begin

end;

function TAutoOpenUnitExpert.GetIDString: string;
begin
  Result := 'TAutoOpenUnitExpert';
end;

function TAutoOpenUnitExpert.GetName: string;
begin
  Result := 'Auto Open Units';
end;

function TAutoOpenUnitExpert.GetState: TWizardState;
begin
  Result := [];
end;

{ TOpenFileIDENotifier }

procedure TOpenFileIDENotifier.AfterCompile(Succeeded: Boolean);
begin

end;

procedure TOpenFileIDENotifier.AfterSave;
begin

end;

procedure TOpenFileIDENotifier.BeforeCompile(const Project: IOTAProject;
  var Cancel: Boolean);
begin

end;

procedure TOpenFileIDENotifier.BeforeSave;
begin

end;

procedure TOpenFileIDENotifier.Destroyed;
begin

end;

function AOU_Tag(const Cmt:Byte): string; inline;
Const CmtTag = 'AutoOpenUnit';
begin
  case Cmt of
    1:   Result := '{' + CmtTag + ' ';
    2:   Result := '(*' + CmtTag + ' ';
    else Result := '';
  end;
end;

// PROBLEM: when i save&close the test project while having
//   .dprfile as the only tab in the editor
//   and then re-open the project
//   there are notifications for .dproj, .dsk, .groupproj
//   but there is just NO notifications for auto-loaded .dpr !!!

// PROBLEM: at least in XE2 when you open .DPROJ file there comes
//   NO notification about opening .DPR or .DPK file at all!!!

// PROBLEM: at least in XE2 there is no Project -> View Source notification

procedure TOpenFileIDENotifier.FileNotification(
  NotifyCode: TOTAFileNotification; const FileName: string;
  var Cancel: Boolean);
Var
  FileContent: string;
  TagStart, TagStart2: Integer;
  TagEnd: Integer;
  UnitName: string;
  FileNameToOpen: string;
  EndTag: string;
begin

  // Problem #2 hack
  if NotifyCode = ofnFileOpened then
     if DPROJ_Opening > '' then
       if FileName = DPROJ_Opening then
       begin
          DPROJ_Opening := '';
          FileNotification(ofnFileOpening, DPROJ_ProjSource, Cancel);
          exit;
       end;

  If NotifyCode <> ofnFileOpening then
     Exit;
  If Not FileExists(FileName) Then
    Exit;

  // no Problem #2 -> no hack needed
  if DPROJ_ProjSource > '' then
    if FileName = DPROJ_ProjSource then
    begin
      DPROJ_Opening := '';
      DPROJ_ProjSource := '';
    end;

  TagEnd := 0;
  FileContent := TFile.ReadAllText(FileName);
  // re-reading file into TStringList on every REPEAT-UNTIL iteration was crazy
  // calling TStringList.GetText thrice on every iteration was crazy
  // also TStringList is slow and heavy (heap fragmentation)

  // Problem #2 hack registering
  if EndsText('.dproj', FileName) then begin
     DPROJ_Opening := FileName;

     TagStart := ScanFF(FileContent, '<MainSource>', TagEnd + 1, True);
     If TagStart > 0 then
     Begin
       TagEnd := ScanFF(FileContent, '</MainSource>', TagStart + 1, False);
       UnitName := Trim(Copy(FileContent, TagStart, TagEnd - TagStart));
       UnitName := ExtractFilePath(FileName) + UnitName;
       DPROJ_ProjSource := UnitName;
     end;

     exit;   // no Pascal comments in XML anyway
  end;

  Repeat
    TagStart := ScanFF(FileContent, AOU_Tag(1), TagEnd + 1, True);
    TagStart2 := ScanFF(FileContent, AOU_Tag(2), TagEnd + 1, True);
    if (TagStart2 > 0) and
       ((TagStart2 < TagStart) or (TagStart <= 0)) then begin
      TagStart := TagStart2;
      EndTag := '*)';
    end else
      EndTag := '}';

    If TagStart > 0 then
    Begin
      TagEnd := ScanFF(FileContent, EndTag, TagStart + 1, False);
      UnitName := Trim(Copy(FileContent, TagStart, TagEnd - TagStart));
      FileNameToOpen := FindUnit(UnitName);

      If FileNameToOpen <> '' then
        (BorlandIDEServices as IOTAActionServices).OpenFile(FileNameToOpen);
    End;
  Until TagStart = 0;
end;

function TOpenFileIDENotifier.FindUnit(UnitName: string): string;
Var
  DelphiPath: string;

  procedure GetSearchDirs(Dirs: TStrings);
  var
    Env: IOTAEnvironmentOptions;
    Path,LibPath,BrowsePath,SearchPath: string;
    Grp: IOTAProjectGroup;
    Proj: IOTAProject;
    Curr,Next: PChar;
    Dir: string;
  begin
    Env:=(BorlandIDEServices as IOTAServices).GetEnvironmentOptions;
    LibPath:=Env.GetOptionValue('LibraryPath');
    BrowsePath:=Env.GetOptionValue('BrowsingPath');
    Grp:=CurrentProjectGroup;
    if Grp<>nil then
    begin
      Proj:=Grp.GetActiveProject;
      if Proj<>nil then
        SearchPath:=Proj.GetProjectOptions.GetOptionValue('UnitDir');
    end;
    Path:=LibPath+';'+BrowsePath+';'+SearchPath;
    if Proj<>nil then
      Path:=ExtractFileDir(Proj.FileName)+';'+Path;
    Path:=StringReplace(Path,'$(DELPHI)',DelphiPath,[rfReplaceAll,rfIgnoreCase]);

    Curr:=PChar(Path);
    Next:=Curr;
    while Next<>nil do
    begin
      Next:=StrScan(Curr,';');
      if Next<>nil then
        Dir:=Copy(Curr,1,Next-Curr)
      else
        Dir:=Curr;
      if Dir<>'' then
      begin
        Dir:=ExpandFileName(Dir);
        if AnsiLastChar(Dir)^<>'\' then
          Dir:=Dir+'\';
        Dirs.Add(Dir);
      end;
      Curr:=Next+1;
    end;
  End;
Var
  Dirs: TStringList;
  I: Integer;
begin
  Result := '';
  DelphiPath:=ExtractFileDir(ExtractFileDir(Application.ExeName));
  Dirs := TStringList.Create;
  Try
    GetSearchDirs(Dirs);
    For I := 0 to Dirs.Count - 1 do
      If FileExists(IncludeTrailingBackslash(Dirs[i]) + UnitName + '.pas') then
      Begin
        Result := IncludeTrailingBackslash(Dirs[i]) + UnitName + '.pas';
        Exit;
      End;
  Finally
    Dirs.Free;
  End;
end;

procedure TOpenFileIDENotifier.Modified;
begin

end;

end.
