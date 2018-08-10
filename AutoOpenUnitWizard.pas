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

unit AutoOpenUnitWizard;

interface

Uses
  SysUtils, Classes, ToolsAPI,
  menus, dialogs, consts, contnrs, registry, windows, Forms, StrUtils;

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

Procedure Register;
Begin
  RegisterPackageWizard(TAutoOpenUnitExpert.Create);
End;

function ScanFF(const Source,Search:String;Start:Integer):Integer;
Var
  p: PChar;
Begin
  p := SearchBuf(PChar(Source), Length(Source), 0, Start-1, Search);
  If p = Nil then
    Result := 0
  else
    Result := p-PChar(Source) + 1;
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

procedure TOpenFileIDENotifier.FileNotification(
  NotifyCode: TOTAFileNotification; const FileName: string;
  var Cancel: Boolean);
Var
  FileContent: TStringList;
  TagStart: Integer;
  TagEnd: Integer;
  UnitName: string;
  FileNameToOpen: string;
begin
  FileContent := TStringList.Create;
  Try
    TagEnd := 0;
    If (NotifyCode = ofnFileOpening) then
    Begin
      Repeat
        If Not FileExists(FileName) Then
          Exit;
        FileContent.LoadFromFile(FileName);
        TagStart := ScanFF(FileContent.Text, '{AutoOpenUnit ', TagEnd + 1);
        If TagStart > 0 then
        Begin
          TagEnd := ScanFF(FileContent.Text, '}', TagStart + 1);
          UnitName := Copy(FileContent.Text, TagStart + 14, TagEnd - TagStart - 14);
          FileNameToOpen := FindUnit(UnitName);

          If FileNameToOpen <> '' then
            (BorlandIDEServices as IOTAActionServices).OpenFile(FileNameToOpen);
        End;
      Until TagStart = 0;
    End;
  Finally
    FileContent.Free;
  End;
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
