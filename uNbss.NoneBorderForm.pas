unit uNbss.NoneBorderForm;

interface

uses
  Windows, Classes, Messages, SysUtils, Forms, GDIPOBJ, GDIPAPI;

const
  sfShadowWidth = 5;

type
  TShadowForm = class(TForm)
  private
    FBlendFunction: BLENDFUNCTION;
  public
		{ Public declarations }
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
    procedure DrawRoundRectangle(AGPGraphics: TGPGraphics; AGPPen: TGPPen; ARect: TRect; ACornerRadius: Integer);
    procedure SetBitmaps;
    function CreateRoundedRectanglePath(ARect: TRect; ACornerRadius: Integer): TGPGraphicsPath;
  end;

  TNoneBorderShadowStyle = class(TComponent)
  private
    FParent: TForm;
    FOldWndProc: TWndMethod;
    FEnabledShadow: Boolean;
    FEnabledNoBorder: Boolean;
    FOriginalBorderStyle: TBorderStyle;
    procedure LocationChanged;
    procedure SizeChanged;
    procedure ShowShadow;
    procedure EnsureNoCaption;
  protected
    FShadowForm: TShadowForm;
    procedure WndProc(var Msg: TMessage); virtual;
    procedure SetEnabledShadow(const Value: Boolean);
    procedure SetEnabledNoBorder(const Value: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property EnabledShadow: Boolean read FEnabledShadow write SetEnabledShadow default True;
    property EnabledNoBorder: Boolean read FEnabledNoBorder write SetEnabledNoBorder default True;
  end;

implementation


{ TSkinForm }
constructor TShadowForm.CreateNew(AOwner: TComponent; Dummy: Integer = 0);
begin
  inherited CreateNew(AOwner);

  SetWindowLong(Self.Handle, GWL_EXSTYLE, GetWindowLong(Self.Handle, GWL_EXSTYLE) or WS_EX_LAYERED or WS_EX_TRANSPARENT);
end;

procedure TShadowForm.DrawRoundRectangle(AGPGraphics: TGPGraphics; AGPPen: TGPPen; ARect: TRect; ACornerRadius: Integer);
var
  pathGPGraphics: TGPGraphicsPath;
begin
  pathGPGraphics := CreateRoundedRectanglePath(ARect, ACornerRadius);
  try
    AGPGraphics.DrawPath(AGPPen, pathGPGraphics);
  finally
    pathGPGraphics.Free;
  end;
end;

procedure TShadowForm.SetBitmaps;
var
  m_GPitmap: TGPBitmap;
  m_GPGraphicBitmap: TGPGraphics;
  m_GPGraphicMemory: TGPGraphics;
  m_GPColor: TGPColor;
  m_GPPen: TGPPen;
  i: Integer;
  m_Alpha: Byte;
  sPoint: TPoint;
  cRect: TRect;
  hdcScreen: HDC;
  hdcMemory: HDC;
  hdcTemp: HDC;
  hBMP: HBITMAP;
  ptWinPos: TPoint;
  ptSrc: TPoint;
  sizeWindow: SIZE;
begin
	// �����봰���С��ͬ�Ĵ�Alphaͨ����32λ͸��ͼ��
  m_GPitmap := TGPBitmap.Create(Self.Width, Self.Height, PixelFormat32bppPARGB);
	// ����ͼ�ζ���
  m_GPGraphicBitmap := TGPGraphics.Create(m_GPitmap);
  m_GPGraphicBitmap.SetSmoothingMode(SmoothingModeAntiAlias);

  m_GPColor := MakeColor(0, 0, 0, 0);

  m_GPPen := TGPPen.Create(m_GPColor, 3);

  for i := 0 to sfShadowWidth do
  begin
    m_Alpha := Trunc(255 * i / 10 / sfShadowWidth);
    m_GPPen.SetColor(MakeColor(m_Alpha, 0, 0, 0));
    sPoint.X := i;
    sPoint.Y := i;

    cRect.Left := sPoint.X;
    cRect.Top := sPoint.Y;
    cRect.Right := sPoint.X + (Self.Width - (2 * i) - 1);
    cRect.Bottom := sPoint.Y + (Self.Height - (2 * i) - 1);

    DrawRoundRectangle(m_GPGraphicBitmap, m_GPPen, cRect, sfShadowWidth - i);
  end;

	// ��������λͼ
  hdcTemp := GetDC(0);
  hdcMemory := CreateCompatibleDC(hdcTemp);
  hBMP := CreateCompatibleBitmap(hdcTemp, m_GPitmap.GetWidth(), m_GPitmap.GetHeight());
  SelectObject(hdcMemory, hBMP);

  FBlendFunction.BlendOp := AC_SRC_OVER;
  FBlendFunction.SourceConstantAlpha := 100;
  FBlendFunction.AlphaFormat := AC_SRC_ALPHA;
  FBlendFunction.BlendFlags := 0;

  hdcScreen := GetDC(0);
  GetWindowRect(Self.Handle, cRect);
  ptWinPos.X := cRect.left;
  ptWinPos.Y := cRect.Top;

  m_GPGraphicMemory := TGPGraphics.Create(hdcMemory);
  m_GPGraphicMemory.SetSmoothingMode(SmoothingModeAntiAlias);
  m_GPGraphicMemory.DrawImage(m_GPitmap, 0, 0, m_GPitmap.GetWidth(), m_GPitmap.GetHeight());

  sizeWindow.cx := m_GPitmap.GetWidth();
  sizeWindow.cy := m_GPitmap.GetHeight();

  ptSrc.X := 0;
  ptSrc.Y := 0;

  UpdateLayeredWindow(Self.Handle, hdcScreen, @ptWinPos, @sizeWindow, hdcMemory, @ptSrc, 0, @FBlendFunction, ULW_ALPHA);

	// �ͷ������Դ
  m_GPGraphicMemory.ReleaseHDC(hdcMemory);

  ReleaseDC(0, hdcScreen);
  hdcScreen := 0;

  ReleaseDC(0, hdcTemp);
  hdcTemp := 0;

  DeleteObject(hBMP);
  hBMP := 0;

  DeleteDC(hdcMemory);
  hdcMemory := 0;

  m_GPitmap.Free;
  m_GPGraphicMemory.Free;
  m_GPGraphicBitmap.Free;
end;

function TShadowForm.CreateRoundedRectanglePath(ARect: TRect; ACornerRadius: Integer): TGPGraphicsPath;
var
  roundedRect: TGPGraphicsPath;
begin
  roundedRect := TGPGraphicsPath.Create;
  roundedRect.AddArc(ARect.TopLeft.X, ARect.TopLeft.Y, ACornerRadius * 2, ACornerRadius * 2, 180, 90);
  roundedRect.AddLine(ARect.TopLeft.X + ACornerRadius, ARect.TopLeft.Y, ARect.Right - ACornerRadius * 2, ARect.TopLeft.Y);
  roundedRect.AddArc(ARect.TopLeft.X + (ARect.Right - ARect.Left) - ACornerRadius * 2, ARect.TopLeft.Y, ACornerRadius * 2, ACornerRadius * 2, 270, 90);
  roundedRect.AddLine(ARect.Right, ARect.TopLeft.Y + ACornerRadius * 2, ARect.Right, ARect.TopLeft.Y + (ARect.Bottom - ARect.Top) - ACornerRadius * 2);
  roundedRect.AddArc(ARect.TopLeft.X + (ARect.Right - ARect.Left) - ACornerRadius * 2, ARect.TopLeft.Y + (ARect.Bottom - ARect.Top) - ACornerRadius * 2, ACornerRadius * 2, ACornerRadius * 2, 0, 90);
  roundedRect.AddLine(ARect.Right - ACornerRadius * 2, ARect.Bottom, ARect.TopLeft.X + ACornerRadius * 2, ARect.Bottom);
  roundedRect.AddArc(ARect.TopLeft.X, ARect.Bottom - ACornerRadius * 2, ACornerRadius * 2, ACornerRadius * 2, 90, 90);
  roundedRect.AddLine(ARect.TopLeft.X, ARect.Bottom - ACornerRadius * 2, ARect.TopLeft.X, ARect.TopLeft.Y + ACornerRadius * 2);
  roundedRect.CloseFigure();
  Result := roundedRect;
end;

constructor TNoneBorderShadowStyle.Create(AOwner: TComponent);
begin
  inherited;
  Assert(AOwner.InheritsFrom(TForm));
  FParent := TForm(AOwner);
  FOriginalBorderStyle := FParent.BorderStyle;
  FOldWndProc := FParent.WindowProc;
  FParent.WindowProc := WndProc;
  FEnabledShadow := True;
  FEnabledNoBorder := True;

  FShadowForm := nil;

  SetEnabledShadow(FEnabledShadow);
  SetEnabledNoBorder(FEnabledNoBorder);

end;

destructor TNoneBorderShadowStyle.Destroy;
begin
  { Restore the host window before the component disappears: the subclass
    must not outlive the object that owns its method pointer. }
  if Assigned(FParent) then
  begin
    FParent.WindowProc := FOldWndProc;
    if FEnabledNoBorder and (FParent.BorderStyle = bsNone) then
      FParent.BorderStyle := FOriginalBorderStyle;
  end;
  inherited;
end;

procedure TNoneBorderShadowStyle.SetEnabledShadow(const Value: Boolean);
begin
  if FEnabledShadow <> Value then
  begin
    FEnabledShadow := Value;
  end;

  ShowShadow;

end;

procedure TNoneBorderShadowStyle.SetEnabledNoBorder(const Value: Boolean);
begin
  if FEnabledNoBorder <> Value then
    FEnabledNoBorder := Value;

  { Remove the caption at the VCL/window-style level, not only by returning 0
    from WM_NCCALCSIZE. The original code only did this on Win32MajorVersion < 6,
    so on Vista+ WS_CAPTION stayed in the real window style. A system modal move
    loop (dragging via HTCAPTION) then made User32/DWM recalculate the non-client
    area from that style and painted the native title bar back over the client.
    BorderStyle makes VCL recreate the window with the correct style bits and
    keeps the property in sync so a later RecreateWnd cannot restore the caption. }
  if FEnabledNoBorder then
  begin
    if FParent.BorderStyle <> bsNone then
      FParent.BorderStyle := bsNone;
  end
  else
  begin
    if FParent.BorderStyle <> FOriginalBorderStyle then
      FParent.BorderStyle := FOriginalBorderStyle;
  end;
end;

procedure TNoneBorderShadowStyle.EnsureNoCaption;
var
  Style: LongInt;
begin
  { Belt-and-braces: DWM can paint a caption even when VCL thinks the form is
    bsNone. Clear the real style bits and ask User32 to recalculate the frame. }
  if csDesigning in ComponentState then
    Exit;
  Style := GetWindowLong(FParent.Handle, GWL_STYLE);
  if (Style and WS_CAPTION) <> 0 then
  begin
    SetWindowLong(FParent.Handle, GWL_STYLE, Style and not WS_CAPTION);
    SetWindowPos(FParent.Handle, 0, 0, 0, 0, 0,
      SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_FRAMECHANGED);
  end;
end;

procedure TNoneBorderShadowStyle.LocationChanged;
begin
  if Assigned(FShadowForm) and (FShadowForm <> nil) then
  begin
    FShadowForm.left := FParent.Left - sfShadowWidth;
    FShadowForm.Top := FParent.Top - sfShadowWidth;
  end;
end;

procedure TNoneBorderShadowStyle.SizeChanged;
begin
  if Assigned(FShadowForm) and (FShadowForm <> nil) then
  begin
    FShadowForm.Height := FParent.Height + sfShadowWidth * 2;
    FShadowForm.Width := FParent.Width + sfShadowWidth * 2;
    FShadowForm.SetBitmaps;
  end;
end;

procedure TNoneBorderShadowStyle.ShowShadow;
begin
  if csDesigning in ComponentState then
  begin
    Exit;
  end;

  if FEnabledShadow then
  begin
    if FParent.WindowState = wsNormal then
    begin
      if not Assigned(FShadowForm) or (FShadowForm = nil) then
      begin
        FShadowForm := TShadowForm.CreateNew(FParent); // ����Ƥ����
        FShadowForm.Color := $000000FF;
        FShadowForm.BorderStyle := bsNone;
        FShadowForm.left := FParent.left - sfShadowWidth;
        FShadowForm.Top := FParent.Top - sfShadowWidth;
        FShadowForm.Height := FParent.Height + sfShadowWidth * 2;
        FShadowForm.Width := FParent.Width + sfShadowWidth * 2;

        FShadowForm.SetBitmaps;
      end;

      LocationChanged;
      FShadowForm.Show;

    end
    else
    begin
      if Assigned(FShadowForm) and (FShadowForm <> nil) then
      begin
        FShadowForm.Hide;
      end;
    end;
  end
  else
  begin
    if Assigned(FShadowForm) and (FShadowForm <> nil) then
    begin
      FShadowForm.Hide;
    end;
  end;
end;

procedure TNoneBorderShadowStyle.WndProc(var Msg: TMessage);
var
  BorderSpace: Integer;
  WMNCCalcSize: TWMNCCalcSize;
  HandledByUs: Boolean;
begin
  if csDesigning in ComponentState then
  begin
    if Assigned(FOldWndProc) then
      FOldWndProc(Msg);
    Exit;
  end;

  HandledByUs := False;

  if FEnabledNoBorder then
  begin
    case Msg.Msg of
      WM_NCCALCSIZE:
        begin
          { Claim the whole window as client area. }
          Msg.Result := 0;

          { wParam = TRUE supplies an NCCALCSIZE_PARAMS record in lParam. With
            wParam = FALSE, lParam is a plain RECT -- touching rgrc[0] then
            corrupts memory. The inset is only needed while maximized, to keep
            the window off the taskbar. }
          if (Msg.WParam = 1) and (FParent.WindowState = wsMaximized) then
          begin
            WMNCCalcSize := TWMNCCalcSize(Msg);
            BorderSpace := GetSystemMetrics(SM_CYFRAME) + GetSystemMetrics(SM_CXPADDEDBORDER);
            Inc(WMNCCalcSize.CalcSize_Params.rgrc[0].Top, BorderSpace);
            Inc(WMNCCalcSize.CalcSize_Params.rgrc[0].Left, BorderSpace);
            Dec(WMNCCalcSize.CalcSize_Params.rgrc[0].Right, BorderSpace);
            Dec(WMNCCalcSize.CalcSize_Params.rgrc[0].Bottom, BorderSpace);
          end;
          HandledByUs := True;
        end;

      WM_NCPAINT, WM_NCACTIVATE:
        begin
          { Root cause of the caption reappearing: any click or drag activates
            the window, DWM then paints the native caption/non-client frame
            straight over the top of our client area. Suppress ALL non-client
            painting while borderless. Return TRUE for WM_NCACTIVATE so VCL
            still treats the window as active; return 0 suppresses the paint. }
          if Msg.Msg = WM_NCACTIVATE then
          begin
            Msg.Result := 1;
            EnsureNoCaption;
          end
          else
            Msg.Result := 0;
          HandledByUs := True;
        end;
    end;
  end;

  if not HandledByUs then
  begin
    case Msg.Msg of
      WM_MOVE, WM_DWMCOMPOSITIONCHANGED, WM_ACTIVATEAPP:
        { Keep the shadow in sync with the host. Never forward the host's
          message record to the shadow form's WndProc: it carries the host's
          coordinates/activation state and corrupts the shadow's own state. }
        ShowShadow;

      WM_SIZE:
        SizeChanged;
    end;

    if Assigned(FOldWndProc) then
      FOldWndProc(Msg);
  end;
end;

end.

