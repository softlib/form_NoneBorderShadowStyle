unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.GDIPOBJ, Winapi.GDIPAPI,
  System.Classes, System.Types, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  uNbss.NoneBorderForm;

type
  TCaptionGlyph = (cgMinimize, cgMaximize, cgRestore, cgClose);

  { A tool window whose text appearance is fully configurable per button.
    It uses GDI+ for both the background and the anti-aliased text. }
  TGdiHintWindow = class(THintWindow)
  private
    FCustomFontName: string;
    FCustomFontSize: Integer;
    FCustomFontColor: TColor;
    FCustomBackColor: TColor;
    FHideTimer: TTimer;
    FPollTimer: TTimer;
    FHintOwner: TObject;
    procedure HideTimerTimer(Sender: TObject);
    procedure PollTimerTimer(Sender: TObject);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure StartAutoHide;
    procedure StopAutoHide;
    { Hide via the Win32 API directly. THintWindow.ActivateHint shows the
      window with ShowWindow(SW_SHOWNOACTIVATE), which never sets VCL's
      FVisible flag; calling Hide/Visible:=False is therefore a no-op and
      leaves the tooltip on screen. }
    procedure ForceHide;
    function MeasureTextSize(const S: string): TGPSizeF;
    property CustomFontName: string read FCustomFontName write FCustomFontName;
    property CustomFontSize: Integer read FCustomFontSize write FCustomFontSize;
    property CustomFontColor: TColor read FCustomFontColor write FCustomFontColor;
    property CustomBackColor: TColor read FCustomBackColor write FCustomBackColor;
    { The button that currently owns the visible hint; used by the poll timer. }
    property HintOwner: TObject read FHintOwner write FHintOwner;
  end;

  { A caption button drawn entirely with GDI+.  SmoothingModeAntiAlias plus
    floating point coordinates give the rounded background and every glyph
    (bar, square, overlapping squares or X) soft, anti-aliased edges. }
  TGdiCaptionButton = class(TCustomControl)
  private
    FGlyph: TCaptionGlyph;
    FHot: Boolean;
    FPressed: Boolean;
    FTracking: Boolean;
    FHintDelayTimer: TTimer;
    FHintFontName: string;
    FHintFontSize: Integer;
    FHintFontColor: TColor;
    FHintBackColor: TColor;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure WMMouseLeave(var Message: TMessage); message WM_MOUSELEAVE;
    procedure StartMouseTracking;
    procedure HintDelayTimerTimer(Sender: TObject);
    procedure SetGlyph(const Value: TCaptionGlyph);
    procedure ShowCustomHint;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure HideCustomHint;
    { Reset hover state without touching the shared hint window. }
    procedure ResetHover;
    { Reset hover state and hide the hint. Called when the cursor leaves. }
    procedure CancelHint;
    { Screen-space hit test used by the form's central watch timer. }
    function CursorInside: Boolean;
    property Glyph: TCaptionGlyph read FGlyph write SetGlyph;
    property HintFontName: string read FHintFontName write FHintFontName;
    property HintFontSize: Integer read FHintFontSize write FHintFontSize;
    property HintFontColor: TColor read FHintFontColor write FHintFontColor;
    property HintBackColor: TColor read FHintBackColor write FHintBackColor;
    property OnClick;
  end;

  TfrmMain = class(TForm)
    pnlTitle: TPanel;
    lblTitle: TLabel;
    pnlContent: TPanel;
    lblIntro: TLabel;
    btnShadow: TButton;
    chkNoBorder: TCheckBox;
    lblHint: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure pnlTitleMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure pnlTitleMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure pnlTitleMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure btnMinClick(Sender: TObject);
    procedure btnMaxClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnShadowClick(Sender: TObject);
    procedure chkNoBorderClick(Sender: TObject);
  private
    FStyle: TNoneBorderShadowStyle;
    FDragging: Boolean;
    FDragOrigin: TPoint;
    FHintWatchTimer: TTimer;
    btnMin: TGdiCaptionButton;
    btnMax: TGdiCaptionButton;
    btnClose: TGdiCaptionButton;
    procedure ApplyRoundCorners;
    procedure CreateCaptionButtons;
    procedure UpdateCaptionButtons;
    procedure HintWatchTimerTimer(Sender: TObject);
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

const
  { sfShadowWidth = 5 in uNbss.NoneBorderForm.pas, and its outermost rounded
    rectangle uses a diameter of 2 * 5 = 10; keep the window region in sync. }
  CornerDiameter = 10;

function ColorToARGB(AColor: TColor; AAlpha: Byte = 255): ARGB;
var
  C: COLORREF;
begin
  C := ColorToRGB(AColor);
  Result := MakeColor(AAlpha, GetRValue(C), GetGValue(C), GetBValue(C));
end;

var
  { One hint window for every caption button: this makes overlapping tooltips
    impossible and gives a single place to manage auto-hide. }
  GHintWindow: TGdiHintWindow = nil;

procedure EnsureSharedHint;
begin
  if GHintWindow = nil then
    GHintWindow := TGdiHintWindow.Create(nil);
end;

procedure HideSharedHint;
begin
  if GHintWindow <> nil then
  begin
    GHintWindow.StopAutoHide;
    GHintWindow.ForceHide;
    { Drop the button reference as soon as the hint is gone, so the poll
      timer can never act on a stale or destroyed button. }
    GHintWindow.HintOwner := nil;
  end;
end;

{ TGdiHintWindow }

constructor TGdiHintWindow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCustomFontName := 'Segoe UI';
  FCustomFontSize := 12;
  FCustomFontColor := clBlack;
  FCustomBackColor := clWindow;
  FHideTimer := TTimer.Create(Self);
  FHideTimer.Enabled := False;
  FHideTimer.Interval := 4000;
  FHideTimer.OnTimer := HideTimerTimer;
  { Short poll while the hint is visible. It checks the REAL cursor position,
    so it still hides the hint when both WM_MOUSELEAVE and CM_MOUSELEAVE are
    missed (which can happen on the second and later hovers). }
  FPollTimer := TTimer.Create(Self);
  FPollTimer.Enabled := False;
  FPollTimer.Interval := 40;
  FPollTimer.OnTimer := PollTimerTimer;
end;

destructor TGdiHintWindow.Destroy;
begin
  FPollTimer.Free;
  FHideTimer.Free;
  inherited Destroy;
end;

procedure TGdiHintWindow.ForceHide;
begin
  if HandleAllocated then
    ShowWindow(Handle, SW_HIDE);
end;

procedure TGdiHintWindow.HideTimerTimer(Sender: TObject);
begin
  StopAutoHide;
  ForceHide;
end;

procedure TGdiHintWindow.PollTimerTimer(Sender: TObject);
var
  P: TPoint;
  R: TRect;
  Btn: TControl;
begin
  if FHintOwner = nil then
    Exit;
  if not (FHintOwner is TControl) then
    Exit;

  Btn := TControl(FHintOwner);
  if not Btn.Visible then
  begin
    HideSharedHint;
    Exit;
  end;

  GetCursorPos(P);
  R := Rect(Btn.ClientToScreen(Point(0, 0)).X,
    Btn.ClientToScreen(Point(0, 0)).Y,
    Btn.ClientToScreen(Point(Btn.Width, Btn.Height)).X,
    Btn.ClientToScreen(Point(Btn.Width, Btn.Height)).Y);
  if not PtInRect(R, P) then
  begin
    if FHintOwner is TGdiCaptionButton then
      TGdiCaptionButton(FHintOwner).CancelHint
    else
      HideSharedHint;
  end;
end;

procedure TGdiHintWindow.StartAutoHide;
begin
  FHideTimer.Enabled := False;
  FHideTimer.Enabled := True;
  FPollTimer.Enabled := False;
  FPollTimer.Enabled := True;
end;

procedure TGdiHintWindow.StopAutoHide;
begin
  FHideTimer.Enabled := False;
  FPollTimer.Enabled := False;
end;

procedure TGdiHintWindow.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  { THintWindow adds WS_BORDER; we draw our own anti-aliased border instead. }
  Params.Style := Params.Style and not WS_BORDER;
end;

function TGdiHintWindow.MeasureTextSize(const S: string): TGPSizeF;
var
  Bmp: TGPBitmap;
  G: TGPGraphics;
  Font: TGPFont;
  LayoutSize: TGPSizeF;
begin
  Result := MakeSize(0.0, 0.0);
  Bmp := TGPBitmap.Create(1, 1);
  try
    G := TGPGraphics.Create(Bmp);
    try
      Font := TGPFont.Create(WideString(FCustomFontName), FCustomFontSize,
        FontStyleRegular, UnitPixel);
      try
        LayoutSize := MakeSize(10000.0, 1000.0);
        G.MeasureString(WideString(S), -1, Font, LayoutSize, nil, Result);
      finally
        Font.Free;
      end;
    finally
      G.Free;
    end;
  finally
    Bmp.Free;
  end;
end;

procedure TGdiHintWindow.Paint;
var
  G: TGPGraphics;
  BackBrush: TGPSolidBrush;
  BorderPen: TGPPen;
  TextBrush: TGPSolidBrush;
  Font: TGPFont;
  StringFormat: TGPStringFormat;
  LayoutRect: TGPRectF;
  W, H: Single;
begin
  W := ClientWidth;
  H := ClientHeight;
  if (W <= 0) or (H <= 0) then
    Exit;

  G := TGPGraphics.Create(Canvas.Handle);
  try
    G.SetSmoothingMode(SmoothingModeAntiAlias);
    G.SetPixelOffsetMode(PixelOffsetModeHighQuality);
    G.Clear(ColorToARGB(FCustomBackColor));

    BackBrush := TGPSolidBrush.Create(ColorToARGB(FCustomBackColor));
    try
      G.FillRectangle(BackBrush, 0.0, 0.0, W, H);
    finally
      BackBrush.Free;
    end;

    BorderPen := TGPPen.Create(MakeColor(100, 0, 0, 0), 1.0);
    try
      G.DrawRectangle(BorderPen, 0.5, 0.5, W - 1.0, H - 1.0);
    finally
      BorderPen.Free;
    end;

    Font := TGPFont.Create(WideString(FCustomFontName), FCustomFontSize,
      FontStyleRegular, UnitPixel);
    try
      StringFormat := TGPStringFormat.Create(StringFormatFlagsNoWrap);
      try
        StringFormat.SetAlignment(StringAlignmentNear);
        StringFormat.SetLineAlignment(StringAlignmentCenter);
        LayoutRect := MakeRect(8.0, 0.0, W - 16.0, H);
        TextBrush := TGPSolidBrush.Create(ColorToARGB(FCustomFontColor));
        try
          G.DrawString(WideString(Caption), -1, Font, LayoutRect,
            StringFormat, TextBrush);
        finally
          TextBrush.Free;
        end;
      finally
        StringFormat.Free;
      end;
    finally
      Font.Free;
    end;
  finally
    G.Free;
  end;
end;

{ TGdiCaptionButton }

constructor TGdiCaptionButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGlyph := cgMinimize;
  FTracking := False;
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  Width := 34;
  Height := 28;

  { Use the custom hint pipeline instead of the global VCL hint window.
    ParentShowHint must also be off, otherwise a parent can turn it back on. }
  ShowHint := False;
  ParentShowHint := False;
  FHintFontName := 'Segoe UI';
  FHintFontSize := 12;
  FHintFontColor := clBlack;
  FHintBackColor := clWindow;
  FHintDelayTimer := TTimer.Create(Self);
  FHintDelayTimer.Enabled := False;
  FHintDelayTimer.Interval := 450;
  FHintDelayTimer.OnTimer := HintDelayTimerTimer;
end;

destructor TGdiCaptionButton.Destroy;
begin
  HideCustomHint;
  FHintDelayTimer.Free;
  inherited Destroy;
end;

procedure TGdiCaptionButton.SetGlyph(const Value: TCaptionGlyph);
begin
  if FGlyph <> Value then
  begin
    FGlyph := Value;
    Invalidate;
  end;
end;

procedure TGdiCaptionButton.HintDelayTimerTimer(Sender: TObject);
begin
  FHintDelayTimer.Enabled := False;
  ShowCustomHint;
end;

procedure TGdiCaptionButton.HideCustomHint;
begin
  if FHintDelayTimer <> nil then
    FHintDelayTimer.Enabled := False;
  HideSharedHint;
end;

procedure TGdiCaptionButton.ResetHover;
begin
  FTracking := False;
  if FHot or FPressed then
  begin
    FHot := False;
    FPressed := False;
    Invalidate;
  end;
  if FHintDelayTimer <> nil then
    FHintDelayTimer.Enabled := False;
end;

procedure TGdiCaptionButton.CancelHint;
begin
  ResetHover;
  HideCustomHint;
end;

function TGdiCaptionButton.CursorInside: Boolean;
var
  P: TPoint;
  R: TRect;
begin
  Result := False;
  if not Visible then
    Exit;
  GetCursorPos(P);
  R := Rect(ClientToScreen(Point(0, 0)).X,
    ClientToScreen(Point(0, 0)).Y,
    ClientToScreen(Point(Width, Height)).X,
    ClientToScreen(Point(Width, Height)).Y);
  Result := PtInRect(R, P);
end;

procedure TGdiCaptionButton.ShowCustomHint;
var
  S: string;
  TextSize: TGPSizeF;
  P: TPoint;
  R: TRect;
  HintW, HintH: Integer;
begin
  S := Hint;
  if S = '' then
    Exit;

  { Always reuse one window: hide first so a second tooltip can never stack
    on top of a previous one, even if CM_MOUSELEAVE was missed. }
  HideSharedHint;
  EnsureSharedHint;

  GHintWindow.CustomFontName := FHintFontName;
  GHintWindow.CustomFontSize := FHintFontSize;
  GHintWindow.CustomFontColor := FHintFontColor;
  GHintWindow.CustomBackColor := FHintBackColor;
  GHintWindow.HintOwner := Self;

  TextSize := GHintWindow.MeasureTextSize(S);
  HintW := Ceil(TextSize.Width) + 20;
  HintH := Ceil(TextSize.Height) + 12;
  if HintW < 60 then
    HintW := 60;

  P := ClientToScreen(Point(0, Height + 3));
  R := Rect(P.X, P.Y, P.X + HintW, P.Y + HintH);
  GHintWindow.ActivateHint(R, S);
  GHintWindow.StartAutoHide;
end;

procedure TGdiCaptionButton.StartMouseTracking;
var
  Track: TTrackMouseEvent;
begin
  if FTracking then
    Exit;
  FillChar(Track, SizeOf(Track), 0);
  Track.cbSize := SizeOf(Track);
  Track.dwFlags := TME_LEAVE;
  Track.hwndTrack := Handle;
  { WM_MOUSELEAVE is a one-shot notification, so re-arm it after every leave. }
  FTracking := TrackMouseEvent(Track);
end;

procedure TGdiCaptionButton.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  FHot := True;
  Invalidate;
  StartMouseTracking;
  FHintDelayTimer.Enabled := True;
end;

procedure TGdiCaptionButton.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  CancelHint;
end;

procedure TGdiCaptionButton.WMMouseLeave(var Message: TMessage);
begin
  { Direct Win32 leave notification: hide at once, do not wait for VCL.
    WM_MOUSELEAVE is one-shot, so FTracking is always cleared here. }
  CancelHint;
end;

procedure TGdiCaptionButton.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  HideCustomHint;
  if Button = mbLeft then
  begin
    FPressed := True;
    SetCapture(Handle);
    Invalidate;
  end;
end;

procedure TGdiCaptionButton.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
  R: TRect;
  NewHot: Boolean;
begin
  inherited MouseMove(Shift, X, Y);

  { Use the REAL cursor position, not the message coordinates. CM_MOUSEENTER
    is not necessarily sent again after the first hover (VCL keeps this
    control as FMouseControl), so hover state must be recovered here. }
  GetCursorPos(P);
  R := Rect(ClientToScreen(Point(0, 0)).X,
    ClientToScreen(Point(0, 0)).Y,
    ClientToScreen(Point(Width, Height)).X,
    ClientToScreen(Point(Width, Height)).Y);
  NewHot := PtInRect(R, P);

  if not NewHot then
  begin
    CancelHint;
    Exit;
  end;

  if not FTracking then
    StartMouseTracking;

  if not FHot then
  begin
    FHot := True;
    Invalidate;
    FHintDelayTimer.Enabled := True;
  end;
end;

procedure TGdiCaptionButton.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  DoClick: Boolean;
begin
  DoClick := FPressed and (Button = mbLeft) and
    PtInRect(ClientRect, Point(X, Y));
  if FPressed then
  begin
    FPressed := False;
    ReleaseCapture;
    Invalidate;
  end;
  inherited MouseUp(Button, Shift, X, Y);
  if DoClick then
    Click;
end;

procedure TGdiCaptionButton.Paint;
var
  G: TGPGraphics;
  Path: TGPGraphicsPath;
  FillBrush: TGPSolidBrush;
  CoverBrush: TGPSolidBrush;
  BorderPen: TGPPen;
  GlyphPen: TGPPen;
  FillColor, BorderColor, GlyphColor, CoverColor: ARGB;
  W, H, Radius: Single;
begin
  W := Width;
  H := Height;
  Radius := 8.0;

  G := TGPGraphics.Create(Canvas.Handle);
  try
    { The essential anti-aliasing settings: smooth curves and half-pixel
      aware offset mode.  All geometry below uses Single coordinates. }
    G.SetSmoothingMode(SmoothingModeAntiAlias);
    G.SetPixelOffsetMode(PixelOffsetModeHighQuality);
    G.Clear(MakeColor(255, 255, 255, 255));

    if FGlyph = cgClose then
    begin
      if FHot or FPressed then
      begin
        FillColor := MakeColor(255, 232, 17, 35);
        BorderColor := MakeColor(255, 194, 0, 10);
        GlyphColor := MakeColor(255, 255, 255, 255);
      end
      else
      begin
        FillColor := MakeColor(0, 255, 255, 255);
        BorderColor := MakeColor(28, 0, 0, 0);
        GlyphColor := MakeColor(255, 55, 55, 55);
      end;
    end
    else
    begin
      if FPressed then
      begin
        FillColor := MakeColor(255, 204, 228, 247);
        BorderColor := MakeColor(255, 100, 170, 220);
      end
      else if FHot then
      begin
        FillColor := MakeColor(255, 229, 241, 251);
        BorderColor := MakeColor(255, 160, 205, 235);
      end
      else
      begin
        FillColor := MakeColor(0, 255, 255, 255);
        BorderColor := MakeColor(28, 0, 0, 0);
      end;
      GlyphColor := MakeColor(255, 55, 55, 55);
    end;

    Path := TGPGraphicsPath.Create;
    try
      Path.AddArc(0.5, 0.5, Radius, Radius, 180, 90);
      Path.AddArc(W - Radius - 0.5, 0.5, Radius, Radius, 270, 90);
      Path.AddArc(W - Radius - 0.5, H - Radius - 0.5, Radius, Radius, 0, 90);
      Path.AddArc(0.5, H - Radius - 0.5, Radius, Radius, 90, 90);
      Path.CloseFigure;

      FillBrush := TGPSolidBrush.Create(FillColor);
      try
        G.FillPath(FillBrush, Path);
      finally
        FillBrush.Free;
      end;

      BorderPen := TGPPen.Create(BorderColor, 1.0);
      try
        G.DrawPath(BorderPen, Path);
      finally
        BorderPen.Free;
      end;
    finally
      Path.Free;
    end;

    GlyphPen := TGPPen.Create(GlyphColor, 1.5);
    try
      GlyphPen.SetLineCap(LineCapRound, LineCapRound, DashCapRound);
      if FGlyph = cgMinimize then
        G.DrawLine(GlyphPen, 10.0, H / 2, W - 10.0, H / 2)
      else if FGlyph = cgClose then
      begin
        G.DrawLine(GlyphPen, 11.0, 11.0, W - 11.0, H - 11.0);
        G.DrawLine(GlyphPen, W - 11.0, 11.0, 11.0, H - 11.0);
      end
      else if FGlyph = cgMaximize then
      begin
        G.DrawRectangle(GlyphPen, 11.0, 8.0, 12.0, 12.0);
      end
      else { cgRestore: two overlapping squares }
      begin
        { Back square, with its left/bottom-left edges omitted because the
          front square will be painted over that area. }
        G.DrawLine(GlyphPen, 13.0, 7.0, 23.0, 7.0);
        G.DrawLine(GlyphPen, 23.0, 7.0, 23.0, 17.0);
        G.DrawLine(GlyphPen, 23.0, 17.0, 13.0, 17.0);

        if FHot or FPressed then
          CoverColor := FillColor
        else
          CoverColor := MakeColor(255, 255, 255, 255);
        CoverBrush := TGPSolidBrush.Create(CoverColor);
        try
          G.FillRectangle(CoverBrush, 9.0, 11.0, 12.0, 12.0);
        finally
          CoverBrush.Free;
        end;
        G.DrawRectangle(GlyphPen, 9.0, 11.0, 12.0, 12.0);
      end;
    finally
      GlyphPen.Free;
    end;
  finally
    G.Free;
  end;
end;

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  { Owner must be a TForm: TNoneBorderShadowStyle asserts this. }
  FStyle := TNoneBorderShadowStyle.Create(Self);
  FStyle.EnabledNoBorder := True;
  FStyle.EnabledShadow := True;
  CreateCaptionButtons;
  ApplyRoundCorners;

  { Central hint watchdog. Unlike per-button mouse tracking (one-shot and
    easily desynchronised from VCL's own tracking), this timer always runs
    and reacts only to the observable truth: is the hint visible, and is the
    real cursor still over one of our buttons? }
  FHintWatchTimer := TTimer.Create(Self);
  FHintWatchTimer.Enabled := False;
  FHintWatchTimer.Interval := 20;
  FHintWatchTimer.OnTimer := HintWatchTimerTimer;
  FHintWatchTimer.Enabled := True;
end;

procedure TfrmMain.CreateCaptionButtons;
begin
  btnClose := TGdiCaptionButton.Create(Self);
  btnClose.Parent := pnlTitle;
  btnClose.Glyph := cgClose;
  btnClose.Hint := 'Close the window';
  btnClose.HintFontName := 'Segoe UI';
  btnClose.HintFontSize := 12;
  btnClose.HintFontColor := clMaroon;
  btnClose.HintBackColor := $00FCE4E4; { BGR: light red }
  btnClose.OnClick := btnCloseClick;
  btnClose.SetBounds(pnlTitle.Width - 42, 10, 34, 28);
  btnClose.Anchors := [akTop, akRight];

  btnMax := TGdiCaptionButton.Create(Self);
  btnMax.Parent := pnlTitle;
  btnMax.Glyph := cgMaximize;
  btnMax.Hint := 'Maximize the window';
  btnMax.HintFontName := 'Segoe UI';
  btnMax.HintFontSize := 12;
  btnMax.HintFontColor := clNavy;
  btnMax.HintBackColor := $00DDEBF7; { BGR: light blue }
  btnMax.OnClick := btnMaxClick;
  btnMax.SetBounds(pnlTitle.Width - 78, 10, 34, 28);
  btnMax.Anchors := [akTop, akRight];

  btnMin := TGdiCaptionButton.Create(Self);
  btnMin.Parent := pnlTitle;
  btnMin.Glyph := cgMinimize;
  btnMin.Hint := 'Minimize the window';
  btnMin.HintFontName := 'Segoe UI';
  btnMin.HintFontSize := 12;
  btnMin.HintFontColor := clMaroon;
  btnMin.HintBackColor := $00FFF2CC; { BGR: light yellow }
  btnMin.OnClick := btnMinClick;
  btnMin.SetBounds(pnlTitle.Width - 114, 10, 34, 28);
  btnMin.Anchors := [akTop, akRight];

  UpdateCaptionButtons;
end;

procedure TfrmMain.UpdateCaptionButtons;
begin
  if btnMax = nil then
    Exit;

  { The native caption has its own system buttons; only show our GDI+ ones
    while the borderless style is active. }
  if not chkNoBorder.Checked then
  begin
    btnMin.HideCustomHint;
    btnMax.HideCustomHint;
    btnClose.HideCustomHint;
  end;
  btnMin.Visible := chkNoBorder.Checked;
  btnMax.Visible := chkNoBorder.Checked;
  btnClose.Visible := chkNoBorder.Checked;

  if WindowState = wsMaximized then
  begin
    btnMax.Glyph := cgRestore;
    btnMax.Hint := 'Restore the window';
  end
  else
  begin
    btnMax.Glyph := cgMaximize;
    btnMax.Hint := 'Maximize the window';
  end;
end;

procedure TfrmMain.HintWatchTimerTimer(Sender: TObject);
var
  P: TPoint;
  OverAnyButton: Boolean;
  R: TRect;

  function CursorOver(B: TGdiCaptionButton): Boolean;
  begin
    Result := False;
    if (B = nil) or (not B.Visible) then
      Exit;
    R := Rect(B.ClientToScreen(Point(0, 0)).X,
      B.ClientToScreen(Point(0, 0)).Y,
      B.ClientToScreen(Point(B.Width, B.Height)).X,
      B.ClientToScreen(Point(B.Width, B.Height)).Y);
    Result := PtInRect(R, P);
  end;

begin
  { Only act while a hint is actually visible: no per-button tracking state
    is involved, so this cannot get out of sync after repeated hovers.
    THintWindow.ActivateHint uses ShowWindow directly, so the VCL Visible
    property may be stale -- ask Windows for the real state instead. }
  if GHintWindow = nil then
    Exit;
  if not GHintWindow.HandleAllocated then
    Exit;
  if not IsWindowVisible(GHintWindow.Handle) then
    Exit;

  GetCursorPos(P);
  OverAnyButton := CursorOver(btnMin) or CursorOver(btnMax) or
    CursorOver(btnClose);

  if not OverAnyButton then
  begin
    HideSharedHint;
    btnMin.ResetHover;
    btnMax.ResetHover;
    btnClose.ResetHover;
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  FHintWatchTimer.Enabled := False;
  FHintWatchTimer.Free;
  FStyle.Free;
end;

procedure TfrmMain.ApplyRoundCorners;
var
  R: HRGN;
begin
  { A maximized window should stay rectangular, and when the native border
    is enabled a round region would clip its caption. }
  if (WindowState = wsMaximized) or (not chkNoBorder.Checked) then
  begin
    SetWindowRgn(Handle, 0, True);
    Exit;
  end;

  R := CreateRoundRectRgn(0, 0, Width + 1, Height + 1,
    CornerDiameter, CornerDiameter);
  if R <> 0 then
    SetWindowRgn(Handle, R, True); { system owns R on success }
end;

procedure TfrmMain.FormResize(Sender: TObject);
begin
  ApplyRoundCorners;
  UpdateCaptionButtons;
end;

procedure TfrmMain.pnlTitleMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  { Manual drag instead of WM_NCLBUTTONDOWN + HTCAPTION. The latter puts
    Windows into a system modal move loop which recalculates the non-client
    area from the real window style and can paint the native caption back. }
  if Button = mbLeft then
  begin
    FDragging := True;
    FDragOrigin := Point(X, Y);
    SetCapture(pnlTitle.Handle);
  end;
end;

procedure TfrmMain.pnlTitleMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  if FDragging then
  begin
    Left := Left + (X - FDragOrigin.X);
    Top := Top + (Y - FDragOrigin.Y);
  end;
end;

procedure TfrmMain.pnlTitleMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if FDragging then
  begin
    FDragging := False;
    ReleaseCapture;
  end;
end;

procedure TfrmMain.btnMinClick(Sender: TObject);
begin
  WindowState := wsMinimized;
end;

procedure TfrmMain.btnMaxClick(Sender: TObject);
begin
  if WindowState = wsMaximized then
    WindowState := wsNormal
  else
    WindowState := wsMaximized;
  UpdateCaptionButtons;
end;

procedure TfrmMain.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.btnShadowClick(Sender: TObject);
begin
  FStyle.EnabledShadow := not FStyle.EnabledShadow;
  if FStyle.EnabledShadow then
    btnShadow.Caption := 'Disable shadow'
  else
    btnShadow.Caption := 'Enable shadow';
end;

procedure TfrmMain.chkNoBorderClick(Sender: TObject);
begin
  FStyle.EnabledNoBorder := chkNoBorder.Checked;
  { Hide the custom caption buttons when the native title bar is restored;
    otherwise both the system buttons and our GDI+ buttons would be visible. }
  UpdateCaptionButtons;
  { Force a fresh WM_NCCALCSIZE so the switch takes effect immediately. }
  SetWindowPos(Handle, 0, 0, 0, 0, 0,
    SWP_FRAMECHANGED or SWP_NOMOVE or SWP_NOSIZE);
  ApplyRoundCorners;
end;

initialization
finalization
  HideSharedHint;
  GHintWindow.Free;

end.
