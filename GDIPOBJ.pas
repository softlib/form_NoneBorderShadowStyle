unit GDIPOBJ;

// Compatibility shim for uNbss.NoneBorderForm.pas under Delphi 11.3 Alexandria.
// See GDIPAPI.pas for details.

interface

uses
  Winapi.GDIPOBJ, Winapi.GDIPAPI;

type
  TGPGraphics     = Winapi.GDIPOBJ.TGPGraphics;
  TGPPen          = Winapi.GDIPOBJ.TGPPen;
  TGPBitmap       = Winapi.GDIPOBJ.TGPBitmap;
  TGPGraphicsPath = Winapi.GDIPOBJ.TGPGraphicsPath;
  TGPColor        = Winapi.GDIPAPI.TGPColor;

implementation

end.
