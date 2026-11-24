unit GDIPAPI;

// Compatibility shim for uNbss.NoneBorderForm.pas under Delphi 11.3 Alexandria.
// The original unit uses the classic names GDIPAPI / GDIPOBJ; 11.3 ships the
// same wrappers as Winapi.GDIPAPI / Winapi.GDIPOBJ.  Aliases are declared
// explicitly because Delphi does not re-export another unit's interface
// symbols through a plain "uses" in the interface section.

interface

uses
  Winapi.GDIPAPI;

type
  ARGB = Winapi.GDIPAPI.ARGB;

const
  PixelFormat32bppPARGB = Winapi.GDIPAPI.PixelFormat32bppPARGB;
  SmoothingModeAntiAlias = Winapi.GDIPAPI.SmoothingModeAntiAlias;

function MakeColor(a, r, g, b: Byte): ARGB; overload; inline;
function MakeColor(r, g, b: Byte): ARGB; overload; inline;

implementation

function MakeColor(a, r, g, b: Byte): ARGB;
begin
  Result := Winapi.GDIPAPI.MakeColor(a, r, g, b);
end;

function MakeColor(r, g, b: Byte): ARGB;
begin
  Result := Winapi.GDIPAPI.MakeColor(r, g, b);
end;

end.
