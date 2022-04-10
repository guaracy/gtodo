unit ugtodo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  Grids, process, LCLType, ComCtrls, Buttons, SynEdit, SynHighlighterDiff,
  synhighlighterunixshellscript;

type

  { TForm1 }

  TForm1 = class(TForm)
    edTarefa: TLabeledEdit;
    FlowPanel1: TFlowPanel;
    PageControl1: TPageControl;
    Panel1: TPanel;
    sgTarefas: TStringGrid;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    SpeedButton3: TSpeedButton;
    sbRecupera: TSpeedButton;
    SynDiffSyn1: TSynDiffSyn;
    SynEdit1: TSynEdit;
    SynUNIXShellScriptSyn1: TSynUNIXShellScriptSyn;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    procedure edTarefaKeyPress(Sender: TObject; var Key: char);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure sgTarefasColRowMoved(Sender: TObject; IsColumn: Boolean; sIndex,
      tIndex: Integer);
    procedure sgTarefasDblClick(Sender: TObject);
    procedure sgTarefasPrepareCanvas(sender: TObject; aCol, aRow: Integer;
      aState: TGridDrawState);
    procedure SpeedButton1Click(Sender: TObject);
    procedure SpeedButton2Click(Sender: TObject);
    procedure SpeedButton3Click(Sender: TObject);
    procedure sbRecuperaClick(Sender: TObject);
    procedure TabSheet2Show(Sender: TObject);
  private
    tDir,
    cDir : string;
    chgfn,
    todofn:string;
    edtMode,
    notGit:Boolean;
  public

  end;

var
  Form1: TForm1;
const
  todoname = 'gtodo.txt';
  changelog = 'changelog.txt';
  status : integer = 0;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormShow(Sender: TObject);
var
  sOut: string;
begin
  cDir:=IncludeTrailingPathDelimiter(GetCurrentDir);
  todofn:=cDir+todoname;
  chgfn:=cDir+changelog;
  notGit:=True;
  sgTarefas.SaveOptions:=soAll;
  if FileExists(todofn) then begin
    sgTarefas.LoadFromFile(todofn);
  end else
    sgTarefas.RowCount:=1;
  sgTarefas.Options:=sgTarefas.Options+[goFixedRowNumbering,goRowSelect];
  if not RunCommandIndir(cDir,'git',['rev-parse','--show-toplevel'],sOut,[poWaitOnExit,poStderrToOutPut,poNoConsole]) then begin
    Caption := 'gtodo : (LOCAL) - '+cDir;
    exit;
  end;
  notGit:=False;
  tDir := Trim(sOut);
  Caption := 'gtodo : (GIT) - '+tDir;
end;

procedure TForm1.sgTarefasColRowMoved(Sender: TObject; IsColumn: Boolean;
  sIndex, tIndex: Integer);
begin
  sgTarefas.SaveToFile(todofn);
end;

procedure TForm1.sgTarefasDblClick(Sender: TObject);
var
  lst: TStringList;
  sOut: string;
   s: String;
begin
  if sgTarefas.RowCount=1 then exit;
  s:=sgTarefas.Cells[1,sgTarefas.Row];
  if MessageDlg('Commit', s+#10#13#10#13'Deseja informar como concluída a tarefa?', mtConfirmation, [mbYes, mbNo],0) = mrYes then begin
    lst := TStringList.Create();
    if FileExists(chgfn) then
      lst.LoadFromFile(chgfn);
    lst.Insert(0,FormatDateTime('YYYY.MM.DD : ',now)+s);
    lst.SaveToFile(chgfn);
    lst.Free;
  end else exit;
  sgTarefas.DeleteRow(sgTarefas.Row);
  sgTarefas.SaveToFile(todofn);
  if notGit then exit;
  if not RunCommandInDir(cDir,'git',['add','.'],sOut,[poWaitOnExit,poStderrToOutPut,poNoConsole]) then begin
    ShowMessage('ERROR : git add .'+sOut);
    exit;
  end;
  if not RunCommandInDir(cDir,'git',['commit','-m',s],sOut,[poWaitOnExit,poStderrToOutPut,poNoConsole]) then begin
    ShowMessage('ERROR : git commit -m '+QuotedStr(s)+sOut);
    exit;
  end;
  ShowMessage('COMMIT OK'#10#13+sOut);
end;

procedure TForm1.sgTarefasPrepareCanvas(sender: TObject; aCol, aRow: Integer;
  aState: TGridDrawState);
begin
  if (aRow < 1) or (aCol < 1) then exit;
  if gdSelected in aState then exit;
  case sgTarefas.Cells[1,aRow][1] of
    '-' : sgTarefas.Canvas.Font.Color:=clGreen;
    '+' : sgTarefas.Canvas.Font.Color:=clRed;
  end;
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
begin
  status:=0;
  SynEdit1.Highlighter:=SynUNIXShellScriptSyn1;
  TabSheet2Show(Self);
end;

procedure TForm1.SpeedButton2Click(Sender: TObject);
begin
  status:=1;
  SynEdit1.Highlighter:=SynDiffSyn1;
  TabSheet2Show(Self);
  SynEdit1.FoldAll(1);
end;

procedure TForm1.SpeedButton3Click(Sender: TObject);
begin
  status:=2;
  SynEdit1.Highlighter:=SynDiffSyn1;
  TabSheet2Show(Self);
end;

procedure TForm1.sbRecuperaClick(Sender: TObject);
begin
end;

procedure TForm1.TabSheet2Show(Sender: TObject);
var
  sOut: string;
  function execGit:Boolean;
  begin
    case status of
      0 : Result :=not RunCommandInDir(cDir,'git',['diff','-P','--compact-summary'],sOut,[poWaitOnExit,poStderrToOutPut,poNoConsole]);
      1 : Result :=not RunCommandInDir(cDir,'git',['diff','-P'],sOut,[poWaitOnExit,poStderrToOutPut,poNoConsole]);
      2 : Result :=not RunCommandInDir(cDir,'git',['log','-P','--oneline'],sOut,[poWaitOnExit,poStderrToOutPut,poNoConsole]);
    else
      sOut:='Indefinido';
      Result:= False;
    end;
  end;

begin
  if execGit then begin //not RunCommandInDir(cDir,'git',['diff','-P'],sOut,[poWaitOnExit,poStderrToOutPut,poNoConsole]) then begin
    ShowMessage('ERROR :  '+sOut);
    exit;
  end;
  SynEdit1.Lines.Text:=sOut;
end;

procedure TForm1.edTarefaKeyPress(Sender: TObject; var Key: char);
var
  s: string;
begin
  if Key <> #13 then exit;
  s:=Trim(edTarefa.Text);
  if s='' then exit;
  if edtMode then begin
    sgTarefas.Cells[1,sgTarefas.Row]:=s;
    edtMode:=False;
  end else begin
    sgTarefas.RowCount:=sgTarefas.RowCount+1;
    sgTarefas.Cells[1,sgTarefas.RowCount-1]:=s;
  end;
  sgTarefas.SaveToFile(todofn);
  edTarefa.Text:='';
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  PageControl1.PageIndex:=0;
end;

procedure TForm1.FormKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
    case Key of
      VK_ESCAPE: begin edtMode:=False; edTarefa.Text:=''; end;
      VK_UP: begin if sgTarefas.Row>1 then sgTarefas.Row:=sgTarefas.Row-1; end;
      VK_DOWN: begin if sgTarefas.Row<sgTarefas.RowCount then sgTarefas.Row:=sgTarefas.Row+1; end;
      VK_E:
        begin
          if not (ssCtrl in Shift) then exit;
          edtMode:=True;
          edTarefa.Text:=sgTarefas.Cells[1,sgTarefas.Row];
          edTarefa.SetFocus;
        end;
      VK_X:
        begin
          if not (ssCtrl in Shift) then exit;
          if sgTarefas.Row<1 then exit;
          if MessageDlg('Commit', sgTarefas.Cells[1,sgTarefas.Row]+#10#13#10#13'Deseja excluir a tarefa?', mtConfirmation, [mbYes, mbNo],0) = mrYes then begin
            sgTarefas.DeleteRow(sgTarefas.Row);
            edTarefa.Text:='';
            sgTarefas.SaveToFile(todofn);
          end;
      end;
    end;
end;

end.

