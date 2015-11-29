unit SMBlueprint;

interface

uses
  System.SysUtils,
  System.Classes,
  DateUtils,
  System.zlib,
  SMBlueprintTypes
//  ,DynaArray3D
  ;

// =============================================================================
// =============================================================================
type

  TSMBlueprint = class
    private
      fChilds:array of TSMBlueprint;
      fParent:TSMBlueprint;
      fDataFiles:array of TSMDataFile;
      fBlockInfos:TBlockInfoArray;
      fBluePrintPath:string;
      fDataName:string;
    //  fBlocks:TDynaArray3D;
      fHeadFile:THead;

      procedure LoadConfig(BlockConfigPath, BlockTypesPath:string);

      procedure BlockDecode(var rawBlock:TBlockRaw; var block:TBlock);
      procedure BlockEncode(var rawBlock:TBlockRaw; var block:TBlock);

      procedure DataLoad(DataFolder:string);
      procedure DataSave(DataFolder:string);
      procedure DataFileLoad(DataFile:string;var data:TSMDataCompressed);
      procedure DataFileSave(DataFile:string;var data:TSMDataCompressed);

      procedure DataChunkZipUn(var ChunkZip:TChunkDataCompressed;var ChunkUnZip:TChunkDataUncompressed);
      procedure DataChunkZip  (var ChunkZip:TChunkDataCompressed;var ChunkUnZip:TChunkDataUncompressed;var sizeOut:integer);
      procedure DataChunkDecode(var chunkRaw:TChunkDataCompressed;var chunkDecomp:TChunkDataDecoded);
      procedure DataChunkEncode(var chunkRaw:TChunkDataCompressed;
                                var chunkDecomp:TChunkDataDecoded;
                                var ChunkZipSize:integer);

      procedure DataDecode(var dataRaw:TSMDataCompressed;var dataDecod:TSMDataDecoded);
      procedure DataEncode(var dataRaw:TSMDataCompressed;var dataDecod:TSMDataDecoded);

      procedure HeadLoad(HeadFile:string;var head:THead);
      procedure HeadRecalc;
      procedure HeadSave(HeadFile:string;var head:THead);
      

      function  DataHeaderCreate:TDataHeader;
      function  DataChunkHeaderCreate(x,y,z:Integer):TChunkHeader;
      function  DataBlockCreate(ID:Word):TBlock;

      procedure DataOptimize;

      procedure CoordinatesDataToWorld(fi,ci,bi:integer;var ar:integer);
      procedure CoordinatesWorldToData(var fi,ci,cci,bi:integer;ar:integer);

//      procedure DataToArray;
//      procedure ArrayToData;

      procedure BlueprintLoad(Path:string);
      procedure BlueprintSave(Path:string);

      function BlockRawToBin(var blockRaw:TBlockRaw):string;
      function BlockRawGetId(var blockRaw:TBlockRaw):Word;
      procedure SwapBytes(p:Pointer;size:Byte);

      procedure PrintHead(var head:THead;var blockInfo:TBlockInfoArray);
      procedure PrintDataHead(var head:TDataHeader);
      procedure PrintDataChunkHead(var head:TChunkHeader);
      procedure PrintDataChunkBody(var chunk:TChunkDataDecoded;var blockInfo:TBlockInfoArray);
      procedure PrintDataChunks(var chunks:TChunkArrayDecoded; var blockInfo:TBlockInfoArray);

      procedure SetBlock(x,y,z:Integer;Value:TBlock);
      function  GetBlock(x,y,z:Integer):TBlock;

      function GetBlockInfo(Id:word):TBlockInfo;

      function GetBounds:THeadBoundBox;


    public

      procedure Load(pathDir: string);
      procedure Save(pathDir: string);

      procedure test;

      function GetBlockNew(ID:Word):TBlock;

      procedure GetStatistics(var stats:THeadElements);

      property Blocks[x,y,z:Integer]:TBlock read GetBlock write SetBlock;
      property BlockInfo[Id:Word]:TBlockInfo read GetBlockInfo;
      property Bounds:THeadBoundBox read GetBounds;


      constructor Create(BlockConfigPath, BlockTypesPath:string);
      destructor Destroy;

  end;




implementation

{ TSMBlueprint }

{
procedure TSMBlueprint.ArrayToData;
var
  f,fx,fy,fz,c,cx,cy,cz,ccx,ccy,ccz,bx,by,bz,wx,wy,wz:Integer;
  fbx,fby,fbz:Integer;
  block:PBlock;
  bounds:TDynaArray3DBounds;
  i,j,k:integer;
  chunkDecoded:TChunkDataDecoded;
  fsize,csize:integer;
  flag:Boolean;
begin
  SetLength(fDataFiles,0);
  fsize:=0;
  fBlocks.Recalculate;
  fBlocks.BoundsUpdate;
  bounds:=fBlocks.Bounds;
  fbx:=bounds.minX-1;
  fby:=bounds.minY-1;
  fbz:=bounds.minZ-1;
  for wx := bounds.minX to bounds.maxX do
  for wy := bounds.minY to bounds.maxY do
  for wz := bounds.minZ to bounds.maxZ do
  begin
    CoordinatesArrayToData(fz,cx,ccx,bx,wx);//file X,Z is actually innner Z,X
    CoordinatesArrayToData(fy,cy,ccy,by,wy);
    CoordinatesArrayToData(fx,cz,ccz,bz,wz);

    //find file with given coordinates
    flag:=false;  
    if fsize>0 then
      for i := 0 to fsize-1 do
        with fDataFiles[i] do
        begin
         if (position.x=fx)AND(position.y=fy)AND(position.z=fz) then
         begin
           f:=i;
           flag:=true;
           Break;
         end;
       end;
    if not flag then //create new file if can not find position
    begin 
      fsize:= fsize+1;
      SetLength(fDataFiles,fsize);
      f:= fsize-1;
      fDataFiles[f].position.x:=fx;
      fDataFiles[f].position.y:=fy;
      fDataFiles[f].position.z:=fz;
      fDataFiles[f].data.header:= DataHeaderCreate;
      SetLength(fDataFiles[f].data.chunks,0);     
    end;
    c:= fDataFiles[f].data.header.index[cx,cy,cz].ID;
    if c=-1 then //add new chunk
    begin
      csize:=Length(fDataFiles[f].data.chunks);
      csize:=csize+1;
      SetLength(fDataFiles[f].data.chunks, csize);
      c:=csize-1;
      fDataFiles[f].data.header.index[cx,cy,cz].ID:=c;
      fDataFiles[f].data.header.time[cx,cy,cz]:= DateTimeToUnix(Now)*1000;
      fDataFiles[f].data.chunks[c].header:= DataChunkHeaderCreate(ccx,ccy,ccz);      
      fDataFiles[f].data.chunks[c].header.time:= DateTimeToUnix(Now)*1000;      
    end;
    //finally write block data
    block:=fBlocks.Voxels[wx,wy,wz]; 
    if block = nil then
      fDataFiles[f].data.chunks[c].data[bx,by,bz]:= DataBlockCreate //empty block
    else
      fDataFiles[f].data.chunks[c].data[bx,by,bz]:= block^;
  end;

  DataOptimize; //remove empty chunks
end;  }

procedure TSMBlueprint.BlockDecode(var rawBlock:TBlockRaw; var block: TBlock);
var flag:byte;
begin
{
Type1
 10-0   ID
 19-11  HP
 	23 	22 	21 	The block facing
Type2
 10-0   ID
 19-11  HP
	23 	22 		The axis of rotation.
    00 : +Y
    01 : -Y
    10 : -Z
    11 : +Z
  21 	20 		The amount of clockwise rotation around the axis of rotation, in 90-degree steps
Type3
 10-0   ID
 18-11  HP
	19 	23 	22 	The axis of rotation.
    000 : +Y
    001 : -Y
    010 : -Z
    011 : +Z
    100 : -X
    101 : +X
21 	20 		The amount of clockwise rotation around the axis of rotation, in 90-degree steps
}


{
bits from 24 to 1
11 to 1 is block ID, 2047 blocks types
18 to 12 is block HP, 255 HP max
24 to 19 is block specific status, like active and/or  facing and rotation


}

   with block do begin
    //get ID
    flag:=$7; //111 bin  9-11(1-3) bits
    ID:= (rawBlock[1] and flag) shl 8;
    ID:= ID + rawBlock[2];          // 1-8 bits
    //if ID = 0 then nothing to do here
    if ID = 0 then
      Exit;
    //get HP
    flag:=$7;// 111 bin  19-17 bits
    HP:= (rawBlock[0] and flag) shl 5;
    flag:=$F8; // 1111 1000 bin  16-12(8-4) bits
    HP:= HP + ((rawBlock[1] and flag) shr 3);
    //get Active status.  Default 0 = active
    if fBlockInfos[ID].canACtivate then begin
      flag:=$8; //1000 bin  20(4) bits
      active:= (rawBlock[0] and flag) shr 3;
    end;
    //whatever we do - store first 5 bits
    //to remember orientation data to replace not implemented code
    orientation:=(rawBlock[0] and $f8) shr 3; // 1111 1000 bin to 1 1111 bin

    //init facing info
    rX:=0;
    rY:=0;
    rZ:=0;
    tX:=0;
    tY:=0;
    tZ:=0;

    flag:=$F0; //1111 0000 bin  24-21(8-5) bits
    //ration
     flag:=(rawBlock[0] and flag);
     flag:= flag shr 4; // 11110000 bin to 1111 bin

    //find facing sides
    // +x (f)orward
    // -x (b)ackward
    // +y (u)p
    // -y (d)own
    // -z (r)ight
    // +z (l)eft
    bGeom:= fBlockInfos[ID].blockGeometry;
    case bGeom of
    //Cube have one primary rectangle face what define ration
      bgCube:begin
{Cube
0000 +x
0001 -x
0010 +y
0011 -y
0100 -z
0101 +z}
        case flag of
          0:rX:=1;
          1:rX:=-1;
          2:rY:=1;
          3:rY:=-1;
          4:rZ:=-1;
          5:rZ:=1;
        end;
      end;

      bgWedge:begin
      //Wedge have two primary rectangle faces what define ration
      //also have 2 triangle faces what not important and defined by rectangles
{Wedge
0000   df
0001   dl
0010   db
0011   dr
}
         case flag of
          0:begin
            rX:=1;
            rY:=-1;
          end;
          1:begin
            rY:=-1;
            rZ:=1
          end;
          2:begin
            rX:=-1;
            rY:=-1;
          end;
          3:begin
            rY:=-1;
            rZ:=-1
          end;
{Wedge
0100   uf
0101   ur
0110   ub
0111   ul
}
          4:begin
            rX:=1;
            rY:=1;
          end;
          5:begin
            rY:=1;
            rZ:=-1
          end;
          6:begin
            rX:=-1;
            rY:=1
          end;
          7:begin
            rY:=1;
            rZ:=1;
          end;
{Wedge
1000   rf
1001   rb
1010   lf
1011   lb}
          8:begin
            rX:=1;
            rZ:=-1
          end;
          9:begin
            rX:=-1;
            rZ:=-1
          end;
          10:begin
            rX:=1;
            rZ:=1
          end;
          11:begin
            rX:=-1;
            rZ:=1
          end;
        end;
      end;

      bgCorner:begin
      //Corner have primary 1 rectangle and 2 triangle faces
      //  what define ration

      //Flag is about 1111 bin
      //plus used additional bit for rotation for Corner block
      //I will place this bit to begin the of "flag"
      //but reference is not changed, so rightest bit in ref is leftest bit in "flag"
      //1000 bin to 1 000 bin and OR with flag 1111 bin
        flag:=flag or ((rawBlock[2] and $8)shl 1);
{Corner
00000 dfr
00010 dbr
00100 dbl
00110 dfl

01000 ufr
01010 ubr
01100 ubl
01110 ufl

10000 bur
10010 bul
10100 bdl
10110 bdr

11000 fdr
11010 fur
11100 ful
11110 fdl

00001 rbd
00011 rbu
00101 rfu
00111 rfd

01001 lbd
01011 lbu
01101 lfu
01111 lfd
}
{Wedge
00000 dfr
00010 dbr
00100 dbl
00110 dfl}
         case flag of
          0:begin
            rY:=-1;
            tX:=1;
            tZ:=-1;
          end;
          1:begin
            rY:=-1;
            tX:=-1;
            tZ:=-1;
          end;
          2:begin
            rY:=-1;
            tX:=-1;
            tZ:=1;
          end;
          3:begin
            rY:=-1;
            tX:=1;
            tZ:=1;
          end;
{Wedge
01000 ufr
01010 ubr
01100 ubl
01110 ufl}
          4:begin
            rY:=1;
            tX:=1;
            tZ:=-1;
          end;
          5:begin
            rY:=1;
            tX:=-1;
            tZ:=-1;
          end;
          6:begin
            rY:=1;
            tX:=-1;
            tZ:=1;
          end;
          7:begin
            rY:=1;
            tX:=1;
            tZ:=1;
          end;
{Wedge
10000 bur
10010 bul
10100 bdl
10110 bdr}
          8:begin
            rX:=-1;
            tY:=1;
            tZ:=-1;
          end;
          9:begin
            rX:=-1;
            tY:=1;
            tZ:=1;
          end;
          10:begin
            rX:=-1;
            tY:=-1;
            tZ:=1;
          end;
          11:begin
            rX:=-1;
            tY:=-1;
            tZ:=-1;
          end;
{Wedge
11000 fdr
11010 fur
11100 ful
11110 fdl}
          12:begin
            rX:=1;
            tY:=-1;
            tZ:=-1;
          end;
          13:begin
            rX:=1;
            tY:=1;
            tZ:=-1;
          end;
          14:begin
            rX:=1;
            tY:=1;
            tZ:=1;
          end;
          15:begin
            rX:=1;
            tY:=-1;
            tZ:=1;
          end;
{Wedge
00001 rbd
00011 rbu
00101 rfu
00111 rfd}
          16:begin
            rZ:=-1;
            tX:=-1;
            tY:=-1;
          end;
          17:begin
            rZ:=-1;
            tX:=-1;
            tY:=1;
          end;
          18:begin
            rZ:=-1;
            tX:=1;
            tY:=1;
          end;
          19:begin
            rZ:=-1;
            tX:=1;
            tY:=-1;
          end;
{Wedge
01001 lbd
01011 lbu
01101 lfu
01111 lfd}
          20:begin
            rZ:=1;
            tX:=-1;
            tY:=-1;
          end;
          21:begin
            rZ:=1;
            tX:=-1;
            tY:=1;
          end;
          22:begin
            rZ:=1;
            tX:=1;
            tY:=1;
          end;
          23:begin
            rZ:=1;
            tX:=1;
            tY:=-1;
          end;
        end;
      end;

      //not implemented yet
      bgXShape:begin

      end;

      bgTetra:begin
      //Tetra ration defined by 3 trianle faces
{TETRA

0000 dfr
0001 dbr
0010 dbl
0011 dfl

0100 ufr
0101 urb
0110 ulb
0111 ulf}
{TETRA

0000 dfr
0001 dbr
0010 dbl
0011 dfl}
        case flag of
          0:begin
            tX:=1;
            tY:=-1;
            tZ:=-1;
          end;
          1:begin
            tX:=-1;
            tY:=-1;
            tZ:=-1;
          end;
          2:begin
            tX:=-1;
            tY:=-1;
            tZ:=1;
          end;
          3:begin
            tX:=1;
            tY:=-1;
            tZ:=1;
          end;
{TETRA
0100 ufr
0101 urb
0110 ulb
0111 ulf}
          4:begin
            tX:=1;
            tY:=1;
            tZ:=-1;
          end;
          5:begin
            tX:=-1;
            tY:=1;
            tZ:=-1;
          end;
          6:begin
            tX:=-1;
            tY:=1;
            tZ:=1;
          end;
          7:begin
            tX:=1;
            tY:=1;
            tZ:=1;
          end;

        end;
      end;
      bgPenta: begin
        //Penta have 3 rectangle faces what define ration
        //and 3 triangle faces, what not impotant and defined by rectangles
{TETRA
0000 dfr
0001 dbr
0010 dbl
0011 dfl

0100 ufr
0101 urb
0110 ulb
0111 ulf}
{TETRA
0000 dfr
0001 dbr
0010 dbl
0011 dfl}
        case flag of
          0:begin
            rX:=1;
            rY:=-1;
            rZ:=-1;
          end;
          1:begin
            rX:=-1;
            rY:=-1;
            rZ:=-1;
          end;
          2:begin
            rX:=-1;
            rY:=-1;
            rZ:=1;
          end;
          3:begin
            rX:=1;
            rY:=-1;
            rZ:=1;
          end;
{TETRA
0100 ufr
0101 urb
0110 ulb
0111 ulf}
          4:begin
            rX:=1;
            rY:=1;
            rZ:=-1;
          end;
          5:begin
            rX:=-1;
            rY:=1;
            rZ:=-1;
          end;
          6:begin
            rX:=-1;
            rY:=1;
            rZ:=1;
          end;
          7:begin
            rX:=1;
            rY:=1;
            rZ:=1;
          end;
        end;
      end;
      //not implemented yet
      bgRail:begin

      end;
    end;//primary case end
  end; // with 'block' end
end;


procedure TSMBlueprint.BlockEncode(var rawBlock: TBlockRaw; var block: TBlock);
var
  flag:Integer;
  orient:Byte;
begin
  rawBlock[0]:= 0; //zero fill initiation
  rawBlock[1]:= 0;
  rawBlock[2]:= 0;

  with block do begin
    // if ID = 0 then nothing to do here
    if ID = 0 then
      Exit;
    //get ID  2047 max
    rawBlock[2]:= ID and $ff; // 000 1111 1111 bin;  1-8 bits
    rawBlock[1]:= rawBlock[1] or ((ID shr 8) and $7); // 111 bin  9-11(1-3) bits
    //get HP  255 max
    rawBlock[1]:= rawBlock[1] or ((HP and $1F) shl $3);// 1 1111 bin to 1111 1000 bin 12-16(4-8) bits
    rawBlock[0]:= rawBlock[0] or ((HP shr 5) and $7); // 1110 0000 bin to 111 bin  17-19(1-3) bits
    //get Active status. Default 0 = active
    if fBlockInfos[ID].canACtivate then
      rawBlock[0]:= rawBlock[0] or (active shl 3); // 1 bin to 1000 bin  20(4) bits
    //flag is XYZxyz
    flag:=0;
    flag:=flag+rX+1;
    flag:=flag*10;
    flag:=flag+rY+1;
    flag:=flag*10;
    flag:=flag+rZ+1;
    flag:=flag*10;
    flag:=flag+tX+1;
    flag:=flag*10;
    flag:=flag+tY+1;
    flag:=flag*10;
    flag:=flag+tZ+1;

    //look at decode comments for information about next
    orient:=0;
    case fBlockInfos[ID].blockGeometry of
      bgCube:
        case flag of
          211111: orient:=0;
          011111: orient:=1;
          121111: orient:=2;
          101111: orient:=3;
          110111: orient:=4;
          112111: orient:=5;
        end;
      bgWedge:
        case flag of
          201111:orient:=0;
          102111:orient:=1;
          001111:orient:=2;
          100111:orient:=3;

          221111:orient:=4;
          120111:orient:=5;
          021111:orient:=6;
          122111:orient:=7;

          210111:orient:=8;
          010111:orient:=9;
          212111:orient:=10;
          012111:orient:=11;
        end;
      bgCorner:
        case flag of
{00000 dfr
00010 dbr
00100 dbl
00110 dfl}
          101210:orient:=0;
          101010:orient:=1;
          101012:orient:=2;
          101212:orient:=3;
{01000 ufr
01010 ubr
01100 ubl
01110 ufl}
          121210:orient:=4;
          121010:orient:=5;
          121012:orient:=6;
          121212:orient:=7;
{10000 bur
10010 bul
10100 bdl
10110 bdr}
          011120:orient:=8;
          011122:orient:=9;
          011102:orient:=10;
          011100:orient:=11;
{11000 fdr
11010 fur
11100 ful
11110 fdl}
          211100:orient:=12;
          211120:orient:=13;
          211122:orient:=14;
          211102:orient:=15;
{00001 rbd
00011 rbu
00101 rfu
00111 rfd}
          110001:orient:=16;
          110021:orient:=17;
          110221:orient:=18;
          110201:orient:=19;
{01001 lbd
01011 lbu
01101 lfu
01111 lfd}
          112001:orient:=20;
          112021:orient:=21;
          112221:orient:=22;
          112201:orient:=23;
        end;

      //not inplemented
      bgXShape:orient:=(orientation shr 4)+((orientation and $f) shl 1);

      bgTetra:
        case flag of
{TETRA
0000 dfr
0001 dbr
0010 dbl
0011 dfl}
          111200:orient:=0;
          111000:orient:=1;
          111002:orient:=2;
          111202:orient:=3;
{TETRA
0100 ufr
0101 urb
0110 ulb
0111 ulf}
          111220:orient:=4;
          111020:orient:=5;
          111022:orient:=6;
          111222:orient:=7;
        end;
      bgPenta:
        case flag of
{0000 dfr
0001 dbr
0010 dbl
0011 dfl}
          200111:orient:=0;
          000111:orient:=1;
          002111:orient:=2;
          202111:orient:=3;
{0100 ufr
0101 urb
0110 ulb
0111 ulf}
          220111:orient:=4;
          020111:orient:=5;
          022111:orient:=6;
          222111:orient:=7;
        end;

      //not inplemented
      bgRail:orient:=(orientation shr 4)+((orientation and $f) shl 1);

    end;// case 'blockStyle' end
  end;//with 'block' end

 orient:=(orient shr 4) +((orient and $f) shl 1);
 orient:=orient shl 3;
 rawBlock[0]:= rawBlock[0] or orient;
end;

function TSMBlueprint.BlockRawGetId(var blockRaw: TBlockRaw): Word;
begin
  Result:= blockRaw[2] +( ( blockRaw[1] and $7 ) shl 8);
end;

function TSMBlueprint.BlockRawToBin(var blockRaw:TBlockRaw): string;
var
 flag:byte;
 p:PByte;
 i:byte;
 s:string;

begin
 s:='';
 for i := 0 to 2 do begin
   p:=PByte(Cardinal(@blockRaw)+i);
   flag:=$80; // bin 1000 0000
   while flag > 0 do begin
     if (p^ and flag)>0 then
       s:=s+'1'
     else
       s:=s+'0';
    flag:=flag shr 1;
   end;
   s:=s+' ';
 end;
 Result:=s;
end;

procedure TSMBlueprint.BlueprintLoad(Path: string);
var
  i:integer;
begin
 Path:=Trim(Path);
 i:=Length(Path);
 if Path[i]='\' then
   SetLength(Path,i-1);
// HeadLoad(Path+'\'+smFileHead,);
 fBluePrintPath:=Path;
 DataLoad(Path+'\DATA');
 HeadLoad(Path+'\'+smFileHead,fHeadFile);
// DataToArray;
end;

procedure TSMBlueprint.BlueprintSave(Path: string);
var
  i:Integer;
begin
 Path:=Trim(Path);
 i:=Length(Path);
 if Path[i]='\' then
   SetLength(Path,i-1);
 if not DirectoryExists(Path) then
   if not  CreateDir(Path) then
     raise Exception.Create('Can not create dir to save files: '+path);
// ArrayToData;
 DataSave(Path+'\DATA');
 HeadRecalc;
 HeadSave(Path+'\'+smFileHead,fHeadFile);
end;

procedure TSMBlueprint.CoordinatesWorldToData(var fi, ci, cci, bi: integer;
  ar: integer);//file, chunk, chunk center, block, array
var
 wi,k:integer;
begin
 wi:= ar + 8 + 128;
 bi:= ((wi mod 16)+16)mod 16; //real math (x mod 16) !
 k:=-1;
 if wi < 0 then
 begin
   wi:= wi - 16 - 256 + 1;
   k:=1;
 end;
 cci:= k*128+(wi div 16)*16;
 ci:= abs(((wi div 16))mod 16);
 fi:= (wi div 16)div 16;
end;

procedure TSMBlueprint.CoordinatesDataToWorld(fi, ci, bi: integer;
  var ar: integer); //file, chunk, block, array
var
  wi,k:integer;

begin
  wi:=fi*16*16;
  k:=1;
  if fi < 0 then
    k:=-1;
  wi:=wi+k*ci*16;
  wi:=wi+bi;
  wi:=wi-8-128+((1-k)div 2)*256;

  ar:=wi;
end;

constructor TSMBlueprint.Create(BlockConfigPath,
  BlockTypesPath: string);
begin
  fDataName:='';
  SetLength(fDataFiles,0);
  //fBlocks:=TDynaArray3D.Create;
  LoadConfig(BlockConfigPath,BlockTypesPath);
end;

function TSMBlueprint.DataBlockCreate(ID:Word): TBlock;
var
  block:TBlock;
begin
  block.bGeom:=fBlockInfos[ID].blockGeometry;
  block.rX:=0;
  block.rY:=0;
  block.rZ:=0;
  block.tX:=0;
  block.tY:=0;
  block.tZ:=0;
  if fBlockInfos[ID].canACtivate then
    block.active:=0    //set as turned off (equals 1)
  else
    block.active:=smBlockPropUseless;
  block.rotation:=smBlockPropUseless;
  block.orientation:=0;
  block.HP:=fBlockInfos[ID].maxHP;
  block.ID:=ID;

  Result:=block;
end;

procedure TSMBlueprint.DataChunkDecode(var chunkRaw: TChunkDataCompressed;
  var chunkDecomp: TChunkDataDecoded);
var
  chunkUnZip:TChunkDataUncompressed;
  i,j,k:integer;
begin
   DataChunkZipUn(chunkRaw,chunkUnZip);
  //decode block data
  for i := 0 to 15 do
  for j := 0 to 15 do
  for k := 0 to 15 do
   BlockDecode(chunkUnZip[i,j,k], chunkDecomp[i,j,k]);
end;

procedure TSMBlueprint.DataChunkEncode(var chunkRaw: TChunkDataCompressed;
  var chunkDecomp: TChunkDataDecoded; var ChunkZipSize: integer);
var
 chunkUnZip:TChunkDataUncompressed;
 chunkUnzipSize:Integer;
 i,j,k:byte;
 pzip,puzip:pointer;
begin
  puzip:=@chunkUnZip;
  //encode block data
  for i := 0 to 15 do
    for j := 0 to 15 do
      for k := 0 to 15 do begin
        BlockEncode(chunkUnZip[i,j,k], chunkDecomp[i,j,k]);
      end;
  DataChunkZip(chunkRaw,chunkUnZip,ChunkZipSize);
end;

function TSMBlueprint.DataChunkHeaderCreate(x,y,z:Integer): TChunkHeader;
var
  chunkHeader:TChunkHeader;
begin
  chunkHeader.ver:= smDataChunkHeaderVersion;;
  chunkHeader.time:= DateTimeToUnix(Now)*1000; 
  chunkHeader.pos.x:= x;
  chunkHeader.pos.y:= y;
  chunkHeader.pos.z:= z;
  chunkHeader.dataByte:= smDataChunkHeaderDataByte;
  chunkHeader.zipedSize:=0;
  Result:= chunkHeader;
end;

procedure TSMBlueprint.DataChunkZip(var ChunkZip: TChunkDataCompressed;
  var ChunkUnZip: TChunkDataUncompressed; var sizeOut: integer);
var
 pin,pout:Pointer;
begin
  FillChar(ChunkZip,smDataChunkDataSize,0);    //first fill chunk with zeroes
  pin:=@ChunkUnZip;
  ZCompress(pin,SizeOf(TChunkDataUncompressed),pout,sizeOut,zcMax);
  if sizeOut > smDataChunkDataSize then             //check size
    raise Exception.Create('Ziped chunk have too big size');
  Move(pout^,ChunkZip,sizeOut);
end;

procedure TSMBlueprint.DataChunkZipUn(var ChunkZip: TChunkDataCompressed;
  var ChunkUnZip: TChunkDataUncompressed);
var
 pin,pout:Pointer;
 sizeOut:integer;
begin
  pin:=@ChunkZip;
  ZDecompress(pin,smDataChunkDataSize,pout,sizeOut);
  if sizeOut <> SizeOf(TChunkDataUncompressed) then             //check size
    raise Exception.Create('Unziped chunk have wrone size');
  Move(pout^,ChunkUnZip,sizeOut);
end;

procedure TSMBlueprint.DataDecode(var dataRaw: TSMDataCompressed;
  var dataDecod: TSMDataDecoded);
var
 i:word;
begin
 {  if Length(dataRaw.chunks)< 1 then
   raise Exception.Create('No chunks to decode or chunk count error');}
  //copy data header
  Move(dataRaw.header,dataDecod.header,SizeOf(TDataHeader));

  SetLength( dataDecod.chunks, Length( dataRaw.chunks ) );
  //extract chunks
  if Length(dataRaw.chunks)>0 then
   for i := 0 to length(dataRaw.chunks)-1 do begin
     Move(dataRaw.chunks[i].header,
          dataDecod.chunks[i].header,
          SizeOf(TChunkHeader));  //copy chunk header
     DataChunkDecode(dataRaw.chunks[i].data,  dataDecod.chunks[i].data); //decode chunk data
   end;

end;

procedure TSMBlueprint.DataEncode(var dataRaw: TSMDataCompressed;
  var dataDecod: TSMDataDecoded);
var
 i:word;
 chunkZipSize:integer;
begin
 {if Length(dataDecod.chunks)< 1 then
   raise Exception.Create('No chunks to encode or chunk count error');}

  //copy header
  Move(dataDecod.header,dataRaw.header,SizeOf(TDataHeader));

  SetLength( dataRaw.chunks, Length( dataDecod.chunks ) );
  //extract chunks
  if Length(dataDecod.chunks)>0 then  
   for i := 0 to length(dataDecod.chunks)-1 do begin
     Move(dataDecod.chunks[i].header,
          dataRaw.chunks[i].header,
          SizeOf(TChunkHeader));//copy chunk header
     DataChunkEncode(dataRaw.chunks[i].data,
                       dataDecod.chunks[i].data,
                       chunkZipSize);  //encode chunk data
     dataRaw.chunks[i].header.zipedSize:=chunkZipSize;
     dataDecod.chunks[i].header.zipedSize:=chunkZipSize;
   end;
end;

procedure TSMBlueprint.DataFileLoad(DataFile: string;
  var data: TSMDataCompressed);
var
  f:file;
  i,j,k:integer;
  chunkCount:word;
  c:word;
begin
  AssignFile(f,DataFile);
  Reset(f,1);

  //get number of chunks in file;

  chunkCount:=(FileSize(f) - SizeOf(TDataHeader)) div smDataChunkSize;

  // File size must be equal to SizeOf(TDataHeader) + N*ChunkSize
  if (FileSize(f) <> (SizeOf(TDataHeader) +  (chunkCount * smDataChunkSize) ) ) then
   raise Exception.Create('File size of '+DataFile+' not fit to expected size');
  i:=FilePos(f);
  i:=FileSize(f);
  //load file header
  BlockRead(f,data.header,SizeOf(TDataHeader));
  //load chunks data

  SetLength(data.chunks, chunkCount);
  if chunkCount > 0 then
   for c := 0 to chunkCount-1 do begin
     BlockRead(f,data.chunks[c],SizeOf(TChunkCompressed));
   end;
  CloseFile(f);

  //due to file consist of big-endian byte order variables
  //and Delphi use little-endian byte order variables
  //need to invert byte order for every variable

  with data.header do begin
    swapbytes(@ver,SizeOf(LongWord));

    for i := 0 to 15 do
      for j := 0 to 15 do
        for k := 0 to 15 do begin
          swapbytes(@(Index[i,j,k].ID),sizeof(LongWord));
          swapbytes(@(Index[i,j,k].len),sizeof(LongWord));
          swapbytes(@(time[i,j,k]),sizeof(UInt64));
        end;
  end;
//  data.chunks[c].header.

  if chunkCount > 0 then
   for c := 0 to chunkCount-1 do
    with data.chunks[c].header do begin
      //do nothing with version
      swapbytes(@time,SizeOf(time));
      swapbytes(@pos,SizeOf(pos));//swap position as solid variable
      //do nothing with dataByte
      swapbytes(@zipedSize,SizeOf(zipedSize));
      //also do nothing with data.chunks[].data
  end;




end;

procedure TSMBlueprint.DataFileSave(DataFile: string;
  var data: TSMDataCompressed);
var
  f:file;
  i,j,k:byte;
  chunkCount:word;
  c:word;
begin

  AssignFile(f,DataFile);
  Rewrite(f,1);

  //due to file consist of big-endian byte order variables
  //and Delphi use little-endian byte order variables
  //need to invert byte order for every variable

   with data.header do begin
    swapbytes(@ver,SizeOf(LongWord));
    for i := 0 to 15 do
      for j := 0 to 15 do
        for k := 0 to 15 do begin
          swapbytes(@(Index[i,j,k].ID),sizeof(LongWord));
          swapbytes(@(Index[i,j,k].len),sizeof(LongWord));
          swapbytes(@(time[i,j,k]),sizeof(UInt64));
        end;
  end;
  //get count of chunks in file;
  chunkCount:=Length(data.chunks);

  if chunkCount > 0 then
   for c := 0 to chunkCount-1 do
    with data.chunks[c].header do begin
      //do nothing with version
      swapbytes(@time,SizeOf(time));
      swapbytes(@pos,SizeOf(pos));//swap position as solid variable
      //do nothing with dataByte
      swapbytes(@zipedSize,SizeOf(zipedSize));
      //also do nothing with data.chunks[].dataw
  end;

  //write file header
  BlockWrite(f,data.header,SizeOf(TDataHeader));
  //write chunks data
  if chunkCount > 0 then
  for c := 0 to chunkCount-1 do
    BlockWrite(f,data.chunks[c],SizeOf(TChunkCompressed));
  CloseFile(f);
end;

function TSMBlueprint.DataHeaderCreate: TDataHeader;
var
  dataHeader:TDataHeader;
  i,j,k:byte;
begin
  with dataHeader do
  begin
    ver:=smDataHeaderVersion;
    for i := 0 to 15 do
    for j := 0 to 15 do
    for k := 0 to 15 do begin
      index[i,j,k].ID:=-1;
      index[i,j,k].len:=0;
      time[i,j,k]:=0;
    end;
  end;
  Result:=dataHeader;
end;

procedure TSMBlueprint.DataLoad(DataFolder: string);
var
  f:file;
  i,j,k:byte;
  filesCount:integer;
  chunkCount:word;
  c:word;
  Search:TSearchRec;
  FindRec:Integer;
  x,y,z:integer;
  s,buf:string;
  name:string;
  DataCompressed:TSMDataCompressed;
  dataDecoded:TSMDataDecoded;
  
begin
 filesCount:=0;
 SetLength(fDataFiles,filesCount);
 name:='';
 FindRec:= FindFirst(DataFolder+'\*.smd2',faAnyFile - faDirectory,Search);
 while FindRec = 0 do begin
   // get data from file name
   s:=Search.Name;

  { i:=Length(s)-Length('.smd2');
   j:=3;
   while j>0 do begin
     if s[i] = '.' then
       j:=j-1;
     i:=i-1;
   end;
   name:=Copy(s,1,i);
   i:=i+1;
   for k := 1 to 3 do begin
     i:=i+1;
     j:=pos(s,'.',i);
     case k of
      1:x:=inttostr(copy(s,i,j-i+1));
      2:y:=inttostr(copy(s,i,j-i+1));
      3:z:=inttostr(copy(s,i,j-i+1));
     end;
     i:=j+1;
   end;       }

  // get data from file name
  i:=Length(s)-Length('.smd2');
  for k:=1 to 3 do begin
    buf:='';
    While true do begin
      if not(s[i] in ['0'..'9','-']) then
      begin
        i:=i-1;
        break;
      end else
      begin
        buf:=s[i]+buf;
        i:=i-1;
      end;
    end;
   case k of
    1:z:=strtoint(buf);
    2:y:=strtoint(buf);
    3:x:=strtoint(buf);
   end;
  end;
  name:=copy(s,1,i);
  if fDataName='' then
    fDataName:=name
  else
    if fDataName<>name then
      raise Exception.Create('Name of DATA files must be same! Error with name: '+name);
  Inc(filesCount);
  SetLength(fDataFiles,filesCount);
  fDataFiles[filesCount-1].position.x:= x;
  fDataFiles[filesCount-1].position.y:= y;
  fDataFiles[filesCount-1].position.z:= z;
  
  DataFileLoad(DataFolder+'\'+Search.Name,DataCompressed);
  DataDecode(DataCompressed,fDataFiles[filesCount-1].data);

  FindRec:=FindNext(Search);
 end;
 FindClose(Search);
end;

//Remove zero chunks and remap indexes of chunks
//after that deletion
procedure TSMBlueprint.DataOptimize;
var
  f,c,bx,by,bz,i,j,k:Integer;
  fsize,csize,count:Integer;
  map,remap:array of Integer;
  flag:Boolean;
begin
  fsize:= Length(fDataFiles);
  if fsize>0 then
  begin
    for f:= 0 to fsize-1 do
    begin
      csize:=Length(fDataFiles[f].data.chunks);
      if csize>0 then
      begin
        SetLength(map,csize);
        SetLength(remap,csize);
        count:=0;//count of not zero chunks
        for c := 0 to csize-1 do //check if chunks is usefull
        begin
          flag:=false;
          for bx := 0 to 15 do
          for by := 0 to 15 do
          for bz := 0 to 15 do
            if fDataFiles[f].data.chunks[c].data[bx,by,bz].ID > 0 then
            begin
              flag:=true;
              Break;
            end;
          if flag then begin
            map[c]:= c;
            count:= count+1;
          end
          else
            map[i]:= -1;
        end;


        for i:=0 to csize-1 do //reset  index info
          remap[i]:=-1;

        i:=0;
        j:=0;
        while j<count do  //calculare remapping array
        begin
          if map[j]<> -1 then
          begin
           remap[j]:=i;
           i:=i+1;
          end;
          j:=j+1;
        end;

        if count>0 then //move chunks
         for i := 0 to csize-1 do
         begin
          if remap[i]<>-1 then
           if remap[i]<>i then
            begin
             fDataFiles[f].data.chunks[remap[i]].header:= fDataFiles[f].data.chunks[i].header;
             Move(fDataFiles[f].data.chunks[i].data,
                  fDataFiles[f].data.chunks[remap[i]].data,
                  SizeOf(TChunkDataDecoded)
             );
            end;
        end;
        SetLength(fDataFiles[f].data.chunks,count); //update array size
        //remap indexes
        for i := 0 to 15 do
        for j := 0 to 15 do
        for k := 0 to 15 do
        begin
          c:=fDataFiles[f].data.header.index[i,j,k].ID;
          if c<>-1 then
          begin
            fDataFiles[f].data.header.index[i,j,k].ID:=remap[c];
            fDataFiles[f].data.header.time[i,j,k]:=0;
          end;
        end;

      end;
    end;
  end;

end;

procedure TSMBlueprint.DataSave(DataFolder: string);
var
  i:Integer;
  s:string;
  x,y,z,id:integer;
  DataCompressed:TSMDataCompressed;
begin
  if not DirectoryExists(DataFolder) then
   if not  CreateDir(DataFolder) then
    raise Exception.Create('Can not create dir to save files: '+DataFolder);

  if Length(fDataFiles) = 0 then
    raise Exception.Create('No DATA files to write');
  for i := Low(fDataFiles) to High(fDataFiles) do begin
    with fDataFiles[i].position do
      s:=DataFolder+'\'+fDataName+'.'+IntToStr(x)+'.'+IntToStr(y)+'.'+IntToStr(z)+'.smd2';
    DataEncode(DataCompressed,fDataFiles[i].data);
    //update chunk size in data header
    for x := 0 to 15 do
     for y := 0 to 15 do
      for z := 0 to 15 do
      begin
      {  id:= fDataFiles[i].data.header.index[x,y,z].ID;
        if id > -1 then
         fDataFiles[i].data.header.index[x,y,z].len :=
           fDataFiles[i].data.chunks[id].header.zipedSize + SizeOf(TChunkHeader);}
         id:= DataCompressed.header.index[x,y,z].ID;
         if id > -1 then
           DataCompressed.header.index[x,y,z].len:=
             DataCompressed.chunks[id].header.zipedSize + SizeOf(TChunkHeader);
      end;
    DataFileSave(s,DataCompressed);
  end;
end;
{
procedure TSMBlueprint.DataToArray;
var
  cx,cy,cz,f,ñ,bx,by,bz,cID,size:Integer;
  wx,wy,wz:Integer;
  fpos,cpos:TVector3i;
 // dataDec:TChunkDataDecoded;
  block:PBlock;
begin
  fBlocks.Destroy;
  fBlocks:=TDynaArray3D.Create;
  size:= Length(fDataFiles);
  if size > 0 then
  for f := 0 to size-1 do
  begin
    fpos:=fDataFiles[f].position;
    for cx := 0 to 15 do
    for cy := 0 to 15 do
    for cz := 0 to 15 do
    begin
      cID:=fDataFiles[f].data.header.index[cx,cy,cz].ID;
      if cID > -1 then
      begin
        cpos:=fDataFiles[f].data.chunks[cID].header.pos;
//        DataChunkDecode(fDataFiles[f].data.chunks[cID].data,dataDec);
        for bx := 0 to 15 do
        for by := 0 to 15 do
        for bz := 0 to 15 do
        begin
          // files coordinates X,Z is a inner coordinates Z,X
          CoordinatesDataToArray(fpos.z,cx,bx,wx);
          CoordinatesDataToArray(fpos.y,cy,by,wy);
          CoordinatesDataToArray(fpos.x,cz,bz,wz);

          if fDataFiles[f].data.chunks[cID].data[bx,by,bz].ID > 0 then
          begin
            new(block);
            block^:=fDataFiles[f].data.chunks[cID].data[bx,by,bz];
            fBlocks.Voxels[wx,wy,wz]:=block;
          end;


        end;
      end;
    end;
  end;
end;
 }
destructor TSMBlueprint.Destroy;
var
 f,c,fs,cs:Integer;
begin
 SetLength(fChilds,0);
 fs:=Length(fDataFiles);
 if fs>0 then
 begin
   for f := 0 to fs-1 do
     SetLength(fDataFiles[f].data.chunks,0);
   SetLength(fDataFiles,0);
 end;
end;

function TSMBlueprint.GetBlock(x, y, z: Integer): TBlock;
var
  bp:PBlock;
  fx,fy,fz,cx,cy,cz,ccx,ccy,ccz,bx,by,bz:integer;//coordinates
  block:TBlock;
  f,c,b:integer; //loop index
  fs,cs,bs:integer; // sizes
  blockSet:Boolean;
begin
  CoordinatesWorldToData(fz,cx,ccx,bx,x);// file Z,X is world X,Z coordinates
  CoordinatesWorldToData(fy,cy,ccy,by,y);
  CoordinatesWorldToData(fx,cz,ccz,bz,z);
  block:=DataBlockCreate(0); // init, always zero
  blockSet:=false;
  fs:=Length(fDataFiles);
  if fs > 0 then
   for f := 0 to fs-1 do
     if (fDataFiles[f].position.x = fx) AND
        (fDataFiles[f].position.y = fy) AND
        (fDataFiles[f].position.z = fz)
     then
     begin
     {  cs:=Length(fDataFiles[f].data.chunks);
       if cs > 0 then
        for c := 0 to cs-1 do
        begin
          with fDataFiles[f].data.chunks[c] do
          begin
            if (header.pos.x = ccx) AND
               (header.pos.y = ccy) AND
               (header.pos.z = ccz)
            then begin
              block:=data[bx,by,bz];
              blockSet:=true;
              Break;
            end;
          end;
        end;
       if blockSet then
         Break; }
       c:= fDataFiles[f].data.header.index[cx,cy,cz].ID;
       if c > -1 then
       begin
        block:= fDataFiles[f].data.chunks[c].data[bx,by,bz];
        Break;
       end;
     end;
  Result:=block;
end;



function TSMBlueprint.GetBlockInfo(Id: word): TBlockInfo;
begin
 Result:=fBlockInfos[Id];
end;

function TSMBlueprint.GetBlockNew(ID:Word): TBlock;
begin
  Result:=DataBlockCreate(ID);
end;

function TSMBlueprint.GetBounds: THeadBoundBox;
begin
  Result:=fHeadFile.bounBox;
end;

procedure TSMBlueprint.GetStatistics(var stats: THeadElements);
begin
  stats.Count:=fHeadFile.stats.Count;
  stats.Elements:=Copy(fHeadFile.stats.Elements,0,fHeadFile.stats.Count);
end;

procedure TSMBlueprint.HeadLoad(HeadFile: string; var head: THead);
var
  i,size:integer;
  f:file;
  b:byte;
begin
  //  AssignFile(f,fileName);
  AssignFile(f,HeadFile);

  Reset(f,1);
  //get size of header beside array of stats
//  BlockRead(f,head.version,SizeOf(head.version));
  BlockRead(f,head.ver, SizeOf(head.ver));
  BlockRead(f,head.entType, SizeOf(head.ver));
  BlockRead(f,head.bounBox.min, SizeOf(head.bounBox.min));
  BlockRead(f,head.bounBox.max, SizeOf(head.bounBox.max));
  BlockRead(f,head.stats.Count, SizeOf(head.stats.Count));
   //swap bytes
  swapbytes(@head.ver, SizeOf(head.ver));
  swapbytes(@head.entType, SizeOf(head.entType));
  swapbytes(@head.bounBox.min, SizeOf(head.bounBox.min));
  swapbytes(@head.bounBox.max, SizeOf(head.bounBox.max));
  swapbytes(@head.stats.Count, SizeOf(head.stats.Count));

  SetLength(head.stats.Elements, head.stats.Count);
  //read array and swap bytes
  for i := 0 to head.stats.Count - 1 do begin
    BlockRead(f,head.stats.Elements[i].ID,
              Sizeof(head.stats.Elements[i].ID));
    BlockRead(f,head.stats.Elements[i].Count,
              Sizeof(head.stats.Elements[i].Count));
    swapbytes(@head.stats.Elements[i].ID,
              SizeOf(head.stats.Elements[i].ID));
    swapbytes(@head.stats.Elements[i].Count,
              SizeOf(head.stats.Elements[i].Count));
  end;
  CloseFile(f);

end;

procedure TSMBlueprint.HeadRecalc;
var
  i,j,k,f,c,b,count:Integer;
  fs,cs:Integer;
  fx,fy,fz,cx,cy,cz,bx,by,bz,wx,wy,wz:integer;//coordinates file/chunk/block/world
  blocks:array[1..smBlockMaxId] of integer;
  Bounds:record minx,miny,minz,maxx,maxy,maxz:Integer;end;
//  blocksBounds:TDynaArray3DBounds;
  p:^TBlock;
begin
  //init
  for i := Low(blocks) to High(blocks) do
    blocks[i]:=0;
  for i := 0 to 2*3-1 do
    PInteger(i+Integer(@Bounds.minx))^:=0;
  //Find new bounds and count blocks
  fs:=Length(fDataFiles);
  if fs>0 then
    for f := 0 to fs-1 do
    begin
      fx:= fDataFiles[f].position.x;
      fy:= fDataFiles[f].position.y;
      fz:= fDataFiles[f].position.z;
      for cx := 0 to 15 do
       for cy := 0 to 15 do
        for cz := 0 to 15 do
        begin
          c:=fDataFiles[f].data.header.index[cx,cy,cz].ID;
          if c > -1 then
          begin
            for bx := 0 to 15 do
             for by := 0 to 15 do
              for bz := 0 to 15 do
              begin
                b:=fDataFiles[f].data.chunks[c].data[bx,by,bz].ID;
                if b>0 then
                begin
                  //update bounds
                  CoordinatesDataToWorld(fz,cx,bx,wx);//file Z,X is world X,Z
                  CoordinatesDataToWorld(fy,cy,by,wy);
                  CoordinatesDataToWorld(fx,cz,bz,wz);

                  if Bounds.minx > wx then
                    Bounds.minx:=wx
                  else
                    if Bounds.maxx < wx then
                      Bounds.maxx:=wx;

                  if Bounds.miny > wy then
                    Bounds.miny:=wy
                  else
                    if Bounds.maxy < wy then
                      Bounds.maxy:=wy;

                  if Bounds.minz > wz then
                    Bounds.minz:=wz
                  else
                    if Bounds.maxz < wz then
                      Bounds.maxz:=wz;

                  //update blocks statistics
                  blocks[b]:=blocks[b]+1;
                end;
              end;
          end;
        end;
    end;

  //set bounds
  //game related offsets of bounds included
  fHeadFile.bounBox.Min.x:= Bounds.minX+smBoundBoxOffeset-2;
  fHeadFile.bounBox.Min.y:= Bounds.minY+smBoundBoxOffeset-2;
  fHeadFile.bounBox.Min.z:= Bounds.minZ+smBoundBoxOffeset-2;
  fHeadFile.bounBox.Max.x:= Bounds.maxX+smBoundBoxOffeset+1;
  fHeadFile.bounBox.Max.y:= Bounds.maxY+smBoundBoxOffeset+1;
  fHeadFile.bounBox.Max.z:= Bounds.maxZ+smBoundBoxOffeset+1;

 //find and set count of block types
  count:=0;
  for i := 1 to smBlockMaxId do
    if blocks[i] > 0 then
      count:= count + 1;
  fHeadFile.stats.Count:= count;
  SetLength(fHeadFile.stats.Elements,count);
  //update  block stats
  i:=0;
  j:=1;
  while j <= smBlockMaxId do begin
    if blocks[j]>0 then begin
      fHeadFile.stats.Elements[i].ID:= j;
      fHeadFile.stats.Elements[i].Count:= blocks[j];
      i:= i+1;
    end;
    j:= j+1;
  end;
end;

procedure TSMBlueprint.HeadSave(HeadFile: string; var head: THead);
var
  i,size:integer;
  f:file;
begin
  AssignFile(f,HeadFile);
  rewrite(f,1);
  //save size before swapping bytes
  size:=  head.stats.Count;
  //get size of header beside array of stats

  swapbytes(@head.ver, SizeOf(head.ver));
  swapbytes(@head.entType, SizeOf(head.entType));
  swapbytes(@head.bounBox.min, SizeOf(head.bounBox.min));
  swapbytes(@head.bounBox.max, SizeOf(head.bounBox.max));
  swapbytes(@head.stats.Count, SizeOf(head.stats.Count));

  BlockWrite(f,head.ver, SizeOf(head.ver));
  BlockWrite(f,head.entType, SizeOf(head.entType));
  BlockWrite(f,head.bounBox.min, SizeOf(head.bounBox.min));
  BlockWrite(f,head.bounBox.max, SizeOf(head.bounBox.max));
  BlockWrite(f,head.stats.Count, SizeOf(head.stats.Count));
   //swap bytes

  // array - swap bytes and write
  for i := 0 to size - 1 do begin
    swapbytes(@head.stats.Elements[i].ID,
              SizeOf(head.stats.Elements[i].ID));
    swapbytes(@head.stats.Elements[i].Count,
              SizeOf(head.stats.Elements[i].Count));
    BlockWrite(f,head.stats.Elements[i].ID,
               Sizeof(head.stats.Elements[i].ID));
    BlockWrite(f,head.stats.Elements[i].Count,
               Sizeof(head.stats.Elements[i].Count));
  end;
  CloseFile(f);
end;

procedure TSMBlueprint.Load(pathDir: string);
begin
  BlueprintLoad(pathDir);
end;

procedure TSMBlueprint.LoadConfig(BlockConfigPath, BlockTypesPath: string);
var
  count,id,p,state,l,r,i:integer;
  s,subs,nameID:string;
  f:TextFile;
begin

  //main initialization
  for i := Low(fBlockInfos) to High(fBlockInfos) do begin
    fBlockInfos[i].ID:=0;
    fBlockInfos[i].nameID:='';
    fBlockInfos[i].blockGeometry:=bgUnknown;
    fBlockInfos[i].canACtivate:=false;
    fBlockInfos[i].invGroup:='';
    fBlockInfos[i].maxHP:=0;
  end;

  //load blocks ID and identificators from BlockTypes file
  AssignFile(f,BlockTypesPath);
  Reset(f);
  while not(Eof(f)) do begin
    Readln(f,s);
    p:= Pos('=',s);
    if p = 0 then  //if not found then skip this line
      Continue;
    subs:= LowerCase(Trim(Copy(s,1,p-1))); // also make it have standart chars
    id:= StrToInt( Copy(s, p+1, Length(s) - p ) );

    fBlockInfos[id].ID:=id;
    fBlockInfos[id].nameID:=subs;
  end;
  CloseFile(f);

  //load another information about blocks from BlockConfig file
  //simple text parsing, no need for XML-parsers (?) or no time
  // to learn XML-parsers
  AssignFile(f,BlockConfigPath);
  Reset(f);
  state:=0;
  while not(Eof(f)) do begin
    readln(f,s);
    case state of
      //if not in <block> section
      0:begin
        if Pos('<Block ',s)=0 then //need wait for <block> section
          Continue;
        state:=1; // Is IN <block> section, change CASE option next time
        //get NameID
        l:=Pos('type="',s)+Length('type="');
        r:=Pos('"',s,l);
        subs:=LowerCase(Trim(Copy(s,l,r-l)));// also make it have standart chars
        //find position of this block name in array
        i:=0;//local flag
        for p := Low(fBlockInfos) to High(fBlockInfos) do begin
          if fBlockInfos[p].nameID = subs then begin
            i:=1;//remember what we got break;
            break;
          end;
        end;
        //if ID was not found then error
        if i = 0 then
          raise Exception.Create('nameID "'+subs+'" not found while parsing '+BlockConfigPath)
      end;
      //if exactly IN <block> section
      1:begin
        // if end of <block> section found
        if Pos('</Block>',s)>0 then begin
          state:=0;
          Continue;
        end;
        //if this block is in group
        l:=pos('<InventoryGroup>',s);
        if l > 0 then begin
          l:= l + Length('<InventoryGroup>');
          r:=Pos('</',s,l);
          subs:=LowerCase(Trim(Copy(s,l,r-l)));
          fBlockInfos[p].invGroup:=subs;
          Continue;
        end;
        //if this block is can be activated
        l:=pos('<CanActivate>',s);
        if l > 0 then begin
          l:= l + Length('<CanActivate>');
          r:=Pos('</',s,l);
          subs:=LowerCase(Trim(Copy(s,l,r-l)));
          if subs = 'true' then  // only check for 'true', else always 'false'
            fBlockInfos[p].canACtivate:=True;
          Continue;
        end;
        //if it is line with block style
        l:=pos('<BlockStyle>',s);
        if l > 0 then begin
          l:= l + Length('<BlockStyle>');
          r:=Pos('</',s,l);
          subs:=Copy(s,l,r-l);
          l:=StrToInt(subs);
          if l > (bgUnknown-1) then   //if block geometry is bigger then known Geometry types
            raise Exception.Create('Block geometry value for '+  //then error, and we need to update this code
                             fBlockInfos[p].nameID +
                             ' is higher then known geomery types');
          fBlockInfos[p].blockGeometry:=l; //convert BlockStyle number to ordinal TBlockGeometry
          Continue;
        end;
        l:=pos('<Hitpoints>',s);
        if l > 0 then begin
          l:= l + Length('<Hitpoints>');
          r:=Pos('</',s,l);
          subs:=Copy(s,l,r-l);
          l:=StrToInt(subs);
          if (l <= 0) or (l > smBlockMaxHP) then
            raise Exception.Create('Block HP is out of bounds');
          fBlockInfos[p].maxHP:= l ;
          Continue;
        end;
      end;
    end;
  end;
  CloseFile(f);

end;

procedure TSMBlueprint.PrintDataChunkBody(var chunk: TChunkDataDecoded;
  var blockInfo: TBlockInfoArray);
var
  i,j,k:Integer;
begin
  Writeln('CHUNK BODY');
  for i := 0 to 15 do
  for j := 0 to 15 do
  for k := 0 to 15 do
   if chunk[i,j,k].ID > 0 then
    Writeln('(',i:2,',',k:2,',',j:2,') ID: ',
            chunk[i,j,k].ID:4,' ',
            blockInfo[chunk[i,j,k].ID].nameID);
  Writeln('CHUNK BODY end');
  Writeln;
end;

procedure TSMBlueprint.PrintDataChunkHead(var head: TChunkHeader);
var
  s:string;
begin
  Writeln('CHUNK HEADER');
  Writeln('Version: ',head.ver);
  with head.pos do
    Writeln('Position: (',x,', ',y,', ',z,')');
  Writeln('Timestamp: ',head.time);
  //timestamp includes milliseconds
  DateTimeToString(s,'',UnixToDateTime( Head.time div 1000 ));
  Writeln('Time: ',s);
  Writeln('Some byte: ',head.dataByte);
  Writeln('Ziped Size: ',head.zipedSize);
  Writeln('CHUNK HEADER end');
  Writeln;
end;

procedure TSMBlueprint.PrintDataChunks(var chunks: TChunkArrayDecoded;
  var blockInfo: TBlockInfoArray);
var i:Integer;
begin
  Writeln('CHUNK LIST');
  if Length(chunks)>0 then
  for i := Low(chunks) to High(chunks) do begin
    Writeln('Chunk #',i);
    PrintDataChunkHead(chunks[i].header);
    PrintDataChunkBody(chunks[i].data,blockInfo);
  end;
  Writeln('CHUNK LIST end');
  Writeln;
end;

procedure TSMBlueprint.PrintDataHead(var head: TDataHeader);
var
  i,j,k:Integer;
  s:string;
begin
  Writeln('DATA HEADER');
  Writeln('Version: ',Head.ver);
  Writeln('Chunks:');
  for i := 0 to 15 do
  for j := 0 to 15 do
  for k := 0 to 15 do
    if head.index[i,j,k].ID >= 0 then begin
      writeln(' Position (',i:2,',',j:2,',',k:2,')');
      writeln('  Chunk Index:',Head.index[i,j,k].ID);
      writeln('  Chunk Timestamp: ',Head.time[i,j,k]:2);
      //timestamp includes milliseconds
      DateTimeToString(s,'',UnixToDateTime( Head.time[i,j,k] div 1000 ));
      Writeln('  Chunk Time: ',s);
  Writeln('DATA HEADER end');
  Writeln;
    end;
end;

procedure TSMBlueprint.PrintHead(var head: THead;
  var blockInfo: TBlockInfoArray);
var s:string;
    i:Integer;
begin
  writeln('HEAD');
  writeln('Version: ',head.ver);
  case head.entType of
    ord(etShip): s:='Ship';
    ord(etShop): s:='Shop';
    ord(etSpaceStation): s:='SpaceStation';
    ord(etAsteroid): s:='Asteroid';
    ord(etPlanet): s:='Planet';
  else s:='Unknown';
  end;
  Writeln('Entity type: ',head.entType,' = ',s);
  Writeln('Bounds:');
  with head.bounBox do begin
    Writeln(' X [',trunc(min.x),',',trunc(max.x),']');
    Writeln(' Y [',trunc(min.y),',',trunc(max.y),']');
    Writeln(' Z [',trunc(min.z),',',trunc(max.z),']');
  end;
  Writeln('Elements:');
  with head.stats do
    for i := 0 to Count-1 do
      Writeln(' ID: ',elements[i].ID:4,' Count: ',elements[i].Count:4,
              ' Name: ',blockInfo[ elements[i].ID ].nameID);
  Writeln('HEAD end');
  Writeln;
end;


procedure TSMBlueprint.Save(pathDir: string);
begin
  BlueprintSave(pathDir);
end;

procedure TSMBlueprint.SetBlock(x, y, z: Integer; Value: TBlock);
var
  fx,fy,fz,cx,cy,cz,ccx,ccy,ccz,bx,by,bz,wx,wy,wz:Integer;//file,chunk,chunk center,block,world
  f,fs,c,cs:Integer;
  blockIsSet:Boolean;
begin
  wx:=x;
  wy:=y;
  wz:=z;
  CoordinatesWorldToData(fz,cx,ccx,bx,wx);//file Z,X is world X,Z
  CoordinatesWorldToData(fy,cy,ccy,by,wy);
  CoordinatesWorldToData(fx,cz,ccz,bz,wz);
  fs:=Length(fDataFiles);
  blockIsSet:=false;
  if fs > 0 then
   for f := 0 to fs do
   begin
     if (fDataFiles[f].position.x = fx) AND
        (fDataFiles[f].position.y = fy) AND
        (fDataFiles[f].position.z = fz)
     then
     begin
        cs:=Length(fDataFiles[f].data.chunks);
        if cs > 0 then
         for c := 0 to cs-1 do
         begin
           if (fDataFiles[f].data.chunks[c].header.pos.x = ccx) AND
              (fDataFiles[f].data.chunks[c].header.pos.y = ccy) AND
              (fDataFiles[f].data.chunks[c].header.pos.z = ccz)
           then
           begin
             fDataFiles[f].data.chunks[c].data[bx,by,bz]:=Value;
             blockIsSet:=true;
           end;
         end;
        //add chunk if not found place to set block
        if not blockIsSet then
        begin
          cs:=cs+1;
          SetLength(fDataFiles[f].data.chunks,cs);
          c:=cs-1;
          fDataFiles[f].data.chunks[c].header:= DataChunkHeaderCreate(ccx,ccy,ccz);
          fDataFiles[f].data.header.index[cx,cy,cz].ID:=c;
          fDataFiles[f].data.header.time[cx,cy,cx]:= fDataFiles[f].data.chunks[c].header.time;
          fDataFiles[f].data.chunks[c].data[bx,by,bz]:=Value;
          blockIsSet:= true;
        end;
     end;
  end;

  if not blockIsSet then   //create file and chunk
  begin
    fs:= fs+1;
    cs:= 0;
    SetLength(fDataFiles,fs);
    SetLength(fDataFiles[fs].data.chunks,cs);
    f:= fs-1;
    fDataFiles[f].position.x:= fx;
    fDataFiles[f].position.y:= fy;
    fDataFiles[f].position.z:= fz;
    fDataFiles[f].data.header:= DataHeaderCreate;
    cs:= cs+1;
    SetLength(fDataFiles[fs].data.chunks,cs);
    c:= cs-1;
    fDataFiles[f].data.header.index[cx,cy,cz].ID:= c;
    fDataFiles[f].data.chunks[c].header:= DataChunkHeaderCreate(ccx,ccy,ccz);
    fDataFiles[f].data.header.time[cx,cy,cz]:= fDataFiles[f].data.chunks[c].header.time;
    fDataFiles[f].data.chunks[c].data[bx,by,bz]:= Value;
  end;
end;


procedure TSMBlueprint.SwapBytes(p: Pointer; size: Byte);
var
  i:Byte;
  temp:Byte;
  pl,pr:PByte;
begin
  if size <= 1 then
    Exit;
  pl:=pbyte(p);
  pr:=pl;
  inc(pr,size-1);
  while LongWord(pl) < LongWord(pr) do
  begin
    temp:=pl^;
    pl^:=pr^;
    pr^:=temp;
    dec(pr);
    inc(pl);
  end;

end;

procedure TSMBlueprint.test;
var
f,fs,c,cs,bx,by,bz:integer;
begin
fs:=Length(fDataFiles);
if fs > 0 then
  for f := 0 to fs-1 do
  begin
    cs:=Length(fDataFiles[f].data.chunks);
    if cs > 0 then
    for c:= 0 to cs-1 do
      for bx := 0 to 15 do
      for by := 0 to 15 do
      for bz := 0 to 15 do
      begin
        if ((by mod 4 )=0)AND
           (fDataFiles[f].data.chunks[c].data[bx,by,bz].ID>1)
        then
        begin
          fDataFiles[f].data.chunks[c].data[bx,by,bz]:= DataBlockCreate(2);
        end;

      end;

  end;

end;

end.
