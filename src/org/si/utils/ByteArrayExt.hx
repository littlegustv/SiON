//----------------------------------------------------------------------------------------------------
// Extended ByteArray
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.utils;

#if flash
import flash.utils.CompressionAlgorithm;
import flash.net.URLLoaderDataFormat;
import flash.events.IOErrorEvent;
import flash.net.URLRequest;
import flash.net.URLLoader;
import flash.utils.Endian;
import flash.utils.ByteArray;
import flash.events.Event;
import flash.display.BitmapData;
#else
import openfl.utils.CompressionAlgorithm;
import openfl.net.URLLoaderDataFormat;
import openfl.events.IOErrorEvent;
import openfl.net.URLRequest;
import openfl.net.URLLoader;
import openfl.utils.Endian;
import openfl.utils.ByteArray;
import openfl.events.Event;
import openfl.display.BitmapData;
#end

typedef CallbackType = Event->Void;

/** Extended ByteArray, png image serialize, IFF chunk structure, FileReference operations. */
class ByteArrayExt
{
    public var bytes:ByteArray;
    public var name:String;

    public function new(copyFrom:ByteArray = null)
    {
        if (copyFrom != null) {
            bytes.writeBytes(copyFrom);
            bytes.endian = copyFrom.endian;
            bytes.position = 0;
        }
    }

    // variables
    //--------------------------------------------------
    private static var crc32 : Array<Int> = null;
    
    // bitmap data operations
    //--------------------------------------------------
    /** translate from BitmapData 
     *  @param bmd BitmapData translating from. 
     *  @return input instance
     */
    public static function fromBitmapData(input : ByteArray, bmd : BitmapData) : ByteArray
    {
        var x : Int;
        var y : Int;
        var i : Int;
        var w : Int = bmd.width;
        var h : Int = bmd.height;
        var len : Int;
        var p : Int;
        input.clear();
        len = bmd.getPixel(w - 1, h - 1);
        y = 0;
        i = 0;
        while (y < h && i < len) {
            x = 0;
            while (x < w && i < len) {
                p = bmd.getPixel(x, y);
                input.writeByte(p >>> 16);
                if (++i >= len)                     break;
                input.writeByte(p >>> 8);
                if (++i >= len)                     break;
                input.writeByte(p);
                x++;
                i++;
            }
            y++;
        }
        input.position = 0;
        return input;
    }
    
    
    /** translate to BitmapData
     *  @param width same as BitmapData's constructor, set 0 to calculate automatically.
     *  @param height same as BitmapData's constructor, set 0 to calculate automatically.
     *  @param transparent same as BitmapData's constructor.
     *  @param fillColor same as BitmapData's constructor.
     *  @return translated BitmapData
     */
    public static function toBitmapData(input : ByteArray, width : Int = 0, height : Int = 0, transparent : Bool = true, fillColor : Int = 0xFFFFFFFF) : BitmapData
    {
        var x : Int = 0;
        var y : Int;
        var reqh : Int;
        var bmd : BitmapData;
        var len : Int = input.length;
        var p : Int;
        if (width == 0) width = ((Math.floor(Math.sqrt(len) + 65535 / 65536)) + 15) & (~15);
        reqh = ((Math.floor(len / width + 65535 / 65536)) + 15) & (~15);
        if (height == 0 || reqh > height)             height = reqh;
        bmd = new BitmapData(width, height, transparent, fillColor);
        input.position = 0;
        y = 0;
        while (y < height) {
            x = 0;
            while (x < width) {
                if (input.bytesAvailable < 3) break;
                bmd.setPixel32(x, y, 0xff000000 | ((input.readUnsignedShort() << 8) | input.readUnsignedByte()));
                x++;
            }
            y++;
        }
        p = 0xff000000;
        if (input.bytesAvailable > 0)             p |= input.readUnsignedByte() << 16;
        if (input.bytesAvailable > 0)             p |= input.readUnsignedByte() << 8;
        if (input.bytesAvailable > 0)             p |= input.readUnsignedByte();
        bmd.setPixel32(x, y, p);
        input.position = 0;
        bmd.setPixel32(x, y, 0xff000000 | input.length);
        return bmd;
    }
    
    
    /** translate to 24bit png data 
     *  @param width png file width, set 0 to calculate automatically.
     *  @param height png file height, set 0 to calculate automatically.
     *  @return ByteArrayExt of PNG data
     */
    public static function toPNGData(input : ByteArray, width : Int = 0, height : Int = 0) : ByteArray
    {
        var i : Int;
        var imax : Int;
        var reqh : Int;
        var pixels : Int = Std.int((input.length + 2) / 3);
        var y : Int;
        var png : ByteArray = new ByteArray();
        var header : ByteArray = new ByteArray();
        var content : ByteArray = new ByteArray();

        //----- write png chunk
        function png_writeChunk(type : Int, data : ByteArray) : Void{
            png.writeUnsignedInt(data.length);
            var crcStartAt : Int = png.position;
            png.writeUnsignedInt(type);
            png.writeBytes(data);
            png.writeUnsignedInt(calculateCRC32(png, crcStartAt, png.position - crcStartAt));
        };

        //----- settings
        if (width == 0)  width = ((Math.floor(Math.sqrt(pixels) + 65535 / 65536)) + 15) & (~15);
        reqh = ((Math.floor(pixels / width + 65535 / 65536)) + 15) & (~15);
        if (height == 0 || reqh > height)             height = reqh;
        header.writeInt(width);  // width  
        header.writeInt(height);  // height  
        header.writeUnsignedInt(0x08020000);  // 24bit RGB  
        header.writeByte(0);
        imax = pixels - width;
        y = 0;
        i = 0;
        while (i < imax){
            content.writeByte(0);
            content.writeBytes(input, i * 3, width * 3);
            i += width;
            y++;
        }
        content.writeByte(0);
        content.writeBytes(input, i * 3, input.length - i * 3);
        imax = (i + width) * 3;
        for (i in input.length...imax) {
            content.writeByte(0);
        }
        imax = width * 3 + 1;
        for (y in (y+1)...height) {
            for (i in 0...imax) {
                content.writeByte(0);
            }
        }
        i = input.length;
        content.position -= 3;
        content.writeByte(i >>> 16);
        content.writeByte(i >>> 8);
        content.writeByte(i);
        content.compress();
        
        //----- write png data
        png.writeUnsignedInt(0x89504e47);
        png.writeUnsignedInt(0x0D0A1A0A);
        png_writeChunk(0x49484452, header);
        png_writeChunk(0x49444154, content);
        png_writeChunk(0x49454E44, new ByteArray());
        png.position = 0;
        
        return png;
    }
    
    
    
    
    // IFF chunk operations
    //--------------------------------------------------
    /** write IFF chunk */
    public static function writeChunk(input : ByteArray, chunkID : String, data : ByteArray, listType : String = null) : Void
    {
        var isList : Bool = (chunkID == "RIFF" || chunkID == "LIST");
        var len : Int = (((data != null)) ? data.length : 0) + (((isList)) ? 4 : 0);
        input.writeMultiByte((chunkID + "    ").substr(0, 4), "us-ascii");
        input.writeInt(len);
        if (isList) {
            if (listType != null)                 input.writeMultiByte((listType + "    ").substr(0, 4), "us-ascii")
            else input.writeMultiByte("    ", "us-ascii");
        }
        if (data != null) {
            input.writeBytes(data);
            if ((len & 1) != 0) input.writeByte(0);
        }
    }
    
    
    /** read (or search) IFF chunk from current position. */
    public static function readChunk(input : ByteArray, bytes : ByteArray, offset : Int = 0, searchChunkID : String = null) : Dynamic
    {
        var id : String;
        var len : Int;
        var type : String = null;
        while (input.bytesAvailable > 0){
            id = input.readMultiByte(4, "us-ascii");
            len = input.readInt();
            if (searchChunkID == null || searchChunkID == id) {
                if (id == "RIFF" || id == "LIST") {
                    type = input.readMultiByte(4, "us-ascii");
                    input.readBytes(bytes, offset, len - 4);
                }
                else {
                    input.readBytes(bytes, offset, len);
                }
                if ((len & 1) != 0) input.readByte();
                bytes.endian = input.endian;
                return {
                    chunkID : id,
                    length : len,
                    listType : type,
                };
            }
            input.position += len + (len & 1);
        }
        return null;
    }
    
    
    /** read all IFF chunks from current position. */
    public static function readAllChunks(input : ByteArray) : Dynamic
    {
        var header : Dynamic;
        var ret : Dynamic = { };
        var pickup : ByteArray;
        while (header = readChunk(input, pickup = new ByteArray())){
            if (Lambda.has(ret, header.chunkID)) {
                if (Std.is(ret[header.chunkID], Array))                     ret[header.chunkID].push(pickup)
                else ret[header.chunkID] = [ret[header.chunkID]];
            }
            else {
                ret[header.chunkID] = pickup;
            }
        }
        return ret;
    }
    
    
    
    
    // URL operations
    //--------------------------------------------------
    /** load from URL 
     *  @param url URL string to load swf file.
     *  @param onComplete handler for Event.COMPLETE. The format is function(bae:ByteArrayExt) : void.
     *  @param onCancel handler for Event.CANCEL. The format is function(e:Event) : void.
     *  @param onError handler for Event.IO_ERROR. The format is function(e:IOErrorEvent) : void.
     */
    public static function load(url : String, onComplete : ByteArray->Void = null, onCancel : Event->Void = null, onError : Event->Void = null) : Void
    {
        var loader : URLLoader = new URLLoader();
        var bae : ByteArray = new ByteArray();

        var _removeAllEventListeners : Event->CallbackType->Void = null;

        function _onLoadCancel(e : Event) : Void {
            _removeAllEventListeners(e, onCancel);
        };
        function _onLoadError(e : Event) : Void {
            _removeAllEventListeners(e, onError);
        };
        function _onLoadComplete(e : Event) : Void{
            var loader : URLLoader = cast(e.target, URLLoader);
            bae.clear();
            bae.writeBytes(cast(loader.data, ByteArray));
            _removeAllEventListeners(e, null);
            bae.position = 0;
            if (onComplete != null) onComplete(bae);
        };

        _removeAllEventListeners = function(e : Event, callback : CallbackType) : Void{
            loader.removeEventListener("complete", _onLoadComplete);
            loader.removeEventListener("cancel", _onLoadCancel);
            loader.removeEventListener("ioError", _onLoadError);
            if (callback != null) callback(e);
        };

        loader.dataFormat = URLLoaderDataFormat.BINARY;
        loader.addEventListener("complete", _onLoadComplete);
        loader.addEventListener("cancel", _onLoadCancel);
        loader.addEventListener("ioError", _onLoadError);
        loader.load(new URLRequest(url));
    }
    
    
    
    
    // FileReference operations
    //--------------------------------------------------
    /** Call FileReference::browse().
     *  @param onComplete handler for Event.COMPLETE. The format is function(bae:ByteArrayExt) : void.
     *  @param onCancel handler for Event.CANCEL. The format is function(e:Event) : void.
     *  @param onError handler for Event.IO_ERROR. The format is function(e:IOErrorEvent) : void.
     *  @param fileFilterName name of file filter.
     *  @param extensions extensions of file filter (like "*.jpg;*.png;*.gif").
     */
    public static function browse(onComplete : ByteArrayExt->Void = null, onCancel : Event->Void = null, onError : IOErrorEvent->Void = null, fileFilterName : String = null, extensions : String = null) : Void
    {
        return;
#if FILE_REFERENCE_ENABLED
        var fr : FileReference = new FileReference();
        var bae : ByteArrayExt = new ByteArray();
        fr.addEventListener("select", function(e : Event) : Void{
                    e.target.removeEventListener(e.type, arguments.callee);
                    fr.addEventListener("complete", _onBrowseComplete);
                    fr.addEventListener("cancel", _onBrowseCancel);
                    fr.addEventListener("ioError", _onBrowseError);
                    fr.load();
                });
        fr.browse(((fileFilterName != null)) ? [new FileFilter(fileFilterName, extensions)] : null);
        
        function _removeAllEventListeners(e : Event, callback : Event->Void) : Void {
            fr.removeEventListener("complete", _onBrowseComplete);
            fr.removeEventListener("cancel", _onBrowseCancel);
            fr.removeEventListener("ioError", _onBrowseError);
            if (callback != null) callback(e);
        };
        function _onBrowseComplete(e : Event) : Void {
            bae.clear();
            bae.writeBytes(e.target.data);
            _removeAllEventListeners(e, null);
            bae.position = 0;
            if (onComplete != null) onComplete(bae);
        };
        function _onBrowseCancel(e : Event) : Void {
            _removeAllEventListeners(e, onCancel);
        };
        function _onBrowseError(e : Event) : Void {
            _removeAllEventListeners(e, onError);
        };
#end
    }
    
    
    /** Call FileReference::save().
     *  @param defaultFileName default file name.
     *  @param onComplete handler for Event.COMPLETE. The format is function(e:Event) : void.
     *  @param onCancel handler for Event.CANCEL. The format is function(e:Event) : void.
     *  @param onError handler for Event.IO_ERROR. The format is function(e:IOErrorEvent) : void.
     */
    public static function save(defaultFileName : String = null, onComplete : Event->Void = null, onCancel : Event->Void = null, onError : IOErrorEvent->Void = null) : Void
    {
#if SAVE_IMPLEMENTED
        var fr : FileReference = new FileReference();
        fr.addEventListener("complete", _onSaveComplete);
        fr.addEventListener("cancel", _onSaveCancel);
        fr.addEventListener("ioError", _onSaveError);
        fr.save(input, defaultFileName);
        
        function _removeAllEventListeners(e : Event, callback : Event->Void) : Void{
            fr.removeEventListener("complete", _onSaveComplete);
            fr.removeEventListener("cancel", _onSaveCancel);
            fr.removeEventListener("ioError", _onSaveError);
            if (callback != null)                 callback(e);
        };
        function _onSaveComplete(e : Event) : Void{_removeAllEventListeners(e, onComplete);
        };
        function _onSaveCancel(e : Event) : Void{_removeAllEventListeners(e, onCancel);
        };
        function _onSaveError(e : Event) : Void{_removeAllEventListeners(e, onError);
        };
#else
        trace("***** Save not implemented.");
#end
    }
    
    
    // zip file operations
    //--------------------------------------------------
    /** Expand zip file including plural files.
     *  @return List of ByteArrayExt
     */
    public static function expandZipFile(input : ByteArrayExt) : Array<ByteArrayExt>
    {
        var bytes : ByteArray = new ByteArray();
        var fileName : String;
        var bae : ByteArrayExt;
        var result : Array<ByteArrayExt> = new Array<ByteArrayExt>();
        var flNameLength : Int;
        var xfldLength : Int;
        var compSize : Int;
        var compMethod : Int;
        var signature : Int;
        
        bytes.endian = Endian.LITTLE_ENDIAN;
        input.bytes.endian = Endian.LITTLE_ENDIAN;
        input.bytes.position = 0;
        while (input.bytes.position < input.bytes.length){
            input.bytes.readBytes(bytes, 0, 30);
            bytes.position = 0;
            signature = bytes.readUnsignedInt();
            if (signature != 0x04034b50) break;  // check signature
            bytes.position = 8;
            compMethod = bytes.readByte();
            bytes.position = 26;
            flNameLength = bytes.readShort();
            bytes.position = 28;
            xfldLength = bytes.readShort();
            
            input.bytes.readBytes(bytes, 30, flNameLength + xfldLength);
            bytes.position = 30;
            fileName = bytes.readUTFBytes(flNameLength);
            bytes.position = 18;
            compSize = bytes.readUnsignedInt();
            
            bae = new ByteArrayExt();
            input.bytes.readBytes(bae.bytes, 0, compSize);
            if (compMethod == 8) bae.bytes.uncompress(CompressionAlgorithm.DEFLATE);
            bae.name = fileName;
            result.push(bae);
        }
        
        return result;
    }
    
    
    
    
    // utilities
    //--------------------------------------------------
    /** calculate crc32 chuck sum */
    public static function calculateCRC32(byteArray : ByteArray, offset : Int = 0, length : Int = 0) : Int
    {
        var i : Int;
        var j : Int;
        var c : Int;
        var currentPosition : Int;
        if (crc32 == null) {
            crc32 = new Array<Int>();
            for (i in 0...256){
                c=i;
                for (j in 0...8){
                    c = Std.int((((c & 1) != 0) ? 0xedb88320 : 0) ^ (c >>> 1));
                }
                crc32[i] = c;
            }
        }
        
        if (length == 0)             length = byteArray.length;
        currentPosition = byteArray.position;
        byteArray.position = offset;
        c=0xffffffff;
        for (i in 0...length){
            j = (c ^ byteArray.readUnsignedByte()) & 255;
            c >>>= 8;
            c ^= crc32[j];
        }
        byteArray.position = currentPosition;
        
        return c ^ 0xffffffff;
    }
}


