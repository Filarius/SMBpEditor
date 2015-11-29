unit SMBlueprintTypes;

interface

Const
 smDataChunkSize = 5120;
 smDataChunkHeaderSize = 26;
 smDataChunkDataSize = SMDataChunkSize - SMDataChunkHeaderSize;
 smBlockMaxId = 2047;
 smBlockMaxHP = 255;
 smBlockPropUseless = -127;
 smBoundBoxOffeset = 1;
 smChunkCenterOffeset = 8;
 smDataChunkIndexMin = -8;
 smDataChunkIndexMax = 7;
 smDataChunkIndexOffset = 8;
 smDataHeaderVersion = 2;
 smDataChunkHeaderVersion = 254;
 smDataChunkHeaderDataByte = 1; //usage unknown;

 smFileHead = 'header.smbph';
 smFileDataType = '.smd2';

 //Block geometry
 bgCube    = 0;
 bgWedge   = 1;
 bgCorner  = 2;
 bgXShape  = 3;
 bgTetra   = 4;
 bgPenta   = 5;
 bgRail    = 6;
 bgUnknown = 7;

 //Entity types
 etShip         = 0;
 etShop         = 1;
 etSpaceStation = 2;
 etAsteroid     = 3;
 etPlanet       = 4;
 etUnknown      = 255;

 //Meta file tags with names
 mTAG_FINISH       = 0;
 mTAG_BYTE         = 1;
 mTAG_SHORT        = 2;
 mTAG_INT          = 3;
 mTAG_LONG         = 4;
 mTAG_FLOAG        = 5;
 mTAG_DOUBLE       = 6;
 mTAG_BYTE_ARRAY   = 7;
 mTAG_STRING       = 8;
 mTAG_VECTOR3F     = 9;
 mTAG_VECTOR3I     = 10;
 mTAG_VECTOR3B     = 11;
 mTAG_LIST         = 12;
 mTAG_STRUCT       = 13;
 mTAG_SERIALIZABLE = 14;
 mTAG_VECTOR4F     = 15;

 //Meta file tags without names
 mTAG_NRGBA			= 241;
 mTAG_NUNK			  = 242;		//added to dev 0.107 bit length: 136
 mTAG_NSTRUCT	  = 243;
 mTAG_NLIST			= 244;
 mTAG_NBYTE3			= 245;
 mTAG_NINT3			= 246;
 mTAG_NFLOAT3		= 247;
 mTAG_NSTRING		= 248;
 mTAG_NBYTEARRAY	= 249;
 mTAG_NDOUBLE		= 250;
 mTAG_NFLOAT			= 251;
 mTAG_NLONG			= 252;
 mTAG_NINT		   	= 253;
 mTAG_NSHORT			= 254;
 mTAG_NBYTE			= 255;


type

  TVector3f = packed record
    x,y,z:Single //4 byte float
  end;

  TVector3i = packed record
    x,y,z:Int32; //4 byte integer
  end;

  TVector3b = packed record
    x,y,z:Byte; //1 byte Byte
  end;

  TVector4f = packed record
    x,y,z,w:Single //4 byte float
  end;

  TBlock = packed record
    bGeom:Byte;
    rX:ShortInt;//rectangle face
    rY:ShortInt;//rectangle face
    rZ:ShortInt;//rectangle face
    tX:ShortInt;//triangle face
    tY:ShortInt;//triangle face
    tZ:ShortInt;//triangle face
    active:ShortInt;
    rotation:ShortInt;
    orientation:byte;
    HP:word;
    ID:word;
  end;
  PBlock = ^TBlock;

  TBlockRaw =
    array [0..2] of byte;

  TChunkIndex = packed record
    ID:integer;
    len:LongWord;
  end;

  TDataHeader = packed record
    ver:LongWord;
    index:array[0..15,0..15,0..15] of TChunkIndex;
    time:array[0..15,0..15,0..15] of UInt64;
  end;
  TChunkDataCompressed =
    array [1..smDataChunkDataSize] of byte;

  TChunkDataUncompressed =
    array[0..15,0..15,0..15] of TBlockRaw;

  TChunkDataDecoded =
    array[0..15,0..15,0..15] of TBlock;

  TChunkHeader = packed record
    ver:Byte;
    time:UInt64;
    pos: TVector3i;
    dataByte:byte; //unknown
    zipedSize:LongWord;
  end;

  TChunkCompressed = packed record
    header:TChunkHeader;
    data:TChunkDataCompressed;
  end;

  TChunkDecoded = packed record
    header:TChunkHeader;
    data:TChunkDataDecoded;
  end;

  TChunkArrayCompressed = array of TChunkCompressed;

  TChunkArrayDecoded = array of TChunkDecoded;

  TSMDataCompressed = packed record
    header:TDataHeader;
    chunks:TChunkArrayCompressed;
  end;

  TSMDataDecoded = record
    header:TDataHeader;
    chunks:TChunkArrayDecoded;
  end;

  TSMDataFile = record
    position:TVector3i;
    data:TSMDataDecoded;
  end;

  TBlockInfo = record
    ID:Word;
    nameID:string;
    blockGeometry:Byte;
    canACtivate:Boolean;
    invGroup:string;
    maxHP:Word;
  end;

  TBlockInfoArray = array [0..smBlockMaxId] of TBlockInfo;

  THeadBoundBox = record
    Min,Max:TVector3f;
  end;

  THeadElementInfo = record
    ID:Word;
    Count:Integer;
  end;

  THeadElements = record
    Count:Integer;
    Elements:array of THeadElementInfo;
  end;

  THead = record
    ver:Integer;
    entType:LongWord;
    bounBox:THeadBoundBox;
    stats:THeadElements;
  end;
implementation

end.
