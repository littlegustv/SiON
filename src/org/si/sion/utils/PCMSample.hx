//----------------------------------------------------------------------------------------------------
// PCM Sample loader/saver
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
// ----------------------------------------------------------------------------------------------------

package org.si.sion.utils;

#if flash
import flash.events.ErrorEvent;
import flash.errors.Error;
import flash.events.*;
import flash.utils.ByteArray;
import flash.utils.Endian;
#else
import openfl.events.ErrorEvent;
import openfl.errors.Error;
import openfl.events.*;
import openfl.utils.ByteArray;
#end

import org.si.utils.ByteArrayExt; 

/** PCM sample loader/saver */  
class PCMSample extends EventDispatcher
{
    public var samples(get, never) : Array<Float>;
    public var sampleLength(get, never) : Int;
    public var sampleRate(get, set) : Float;
    public var channels(get, set) : Int;
    public var bitRate(get, set) : Int;
    public var waveDataChunks(get, never) : Dynamic;
    public var waveData(get, never) : ByteArray;
    public var waveDataSampleRate(get, never) : Float;
    public var waveDataBitRate(get, never) : Int;
    public var waveDataChannels(get, never) : Int;
    public var internalSampleRate(get, never) : Float;
    public var internalChannels(get, never) : Int;
  
    // variables    
    // --------------------------------------------------    
    /** You should not change this property into "acid" ! */  
    public static var basicInfoChunkID : String = "sinf";  
    
    /** extended chunk for SiON */  
    public static var extendedInfoChunkID : String = "SiON";  
    
    /** flags: 0x01 = oneshot, 0x02 = rootSet, 0x04 = stretch, 0x08 = diskbased */  
    public var sampleType : Int;  
    
    // int    /** MIDI note number of base frequency */ 
    public var baseNote : Int;  
    
    // short    /** beat count */  
    public var beatCount : Int;  
    
    // int    /** denominator of time signature */  
    public var timeSignatureDenominator : Int;

    // short    /** number of time signature */
    public var timeSignatureNumber : Int;

    // short    /** beat per minutes */
    public var bpm : Float;

    // float    /** chunks of wave data */
    private var _waveDataChunks : Dynamic = null;

    /** wave data */
    private var _waveData : ByteArray = null;

    /** wave data format ID */
    private var _waveDataFormatID : Int;

    /** wave data sample rate */
    private var _waveDataSampleRate : Float;

    /** wave data bit rate */
    private var _waveDataBitRate : Int;

    /** wave data channel count */
    private var _waveDataChannels : Int;

    /** converted sample cache */
    private var _cache : Array<Float>;

    /** converted sample cache sample rate */
    private var _cacheSampleRate : Float;

    /** converted sample cache channel count */
    private var _cacheChannels : Int;

    /** sample rate of output */
    private var _outputSampleRate : Float;

    /** channel count of output */
    private var _outputChannels : Int;

    /** bit rate of wave file */
    private var _outputBitRate : Int;

    /** internal wave sample in 44.1kHz Number */
    private var _samples : Array<Float>;

    /** channel count of internal wave sample */
    private var _channels : Int;

    /** sample rate of internal wave sample */
    private var _sampleRate : Int;

    /** append position */
    private var _appendPosition : Int;

    /** extract position */
    private var _extractPosition : Float;

    // properties
    // --------------------------------------------------
    /** samples in Array<Number> with properties of sampleRate and channels. */
    private function get_samples() : Array<Float>{
        if (_outputSampleRate == _sampleRate && _outputChannels == _channels) {
            //trace("get sample from raw sample");
            return _samples;
        }

        if (_outputSampleRate == _cacheSampleRate && _outputChannels == _cacheChannels) {
            //trace("get sample from cache");
            return _cache;
        }

        _cacheChannels = _outputChannels;
        _cacheSampleRate = _outputSampleRate;
        _convertSampleRate(_samples, _channels, _sampleRate, _cache, _cacheChannels, _cacheSampleRate, true);
        //trace("get sample with convert");
        return _cache;
    }

    /** sample length */
    private function get_sampleLength() : Int{
        var sampleLength : Int = _samples.length >> (_channels - 1);
        return Math.floor(sampleLength * _outputSampleRate / _sampleRate);
    }

    /** sample rate [Hz] */
    private function get_sampleRate() : Float{
        return _outputSampleRate;
    }

    private function set_sampleRate(rate : Float) : Float{
        _outputSampleRate = ((rate == 0)) ? _sampleRate : rate;
        return rate;
    }  
    
    /** channel count, 1 for monoral, 2 for stereo */  
    private function get_channels() : Int{
        return _outputChannels;
    }
    
    private function set_channels(count : Int) : Int{
        if (count != 1 && count != 2) throw new Error("channel count of 1 or 2 is only available.");
        _outputChannels = count;
        return count;
    }
      
    /** bit rate, this function is used only for saveWaveByteArray, 8 or 16 is available. */  
    private function get_bitRate() : Int{
        return _outputBitRate;
    }
    private function set_bitRate(rate : Int) : Int{
        if (rate != 8 && rate != 16 && rate != 24 && rate != 32) throw new Error("bitRate of " + Std.string(rate) + " is not avairable.");
        _outputBitRate = rate;
        return rate;
    }  
    
    /** chunks of wave file, this property is only available after loadWaveFromByteArray(). */  
    private function get_waveDataChunks() : Dynamic{
        return _waveDataChunks;
    }  
    
    /** wave sample data of original wave file, this property is only available after loadWaveFromByteArray() or saveWaveAsByteArray(). */  
    private function get_waveData() : ByteArray{
        return _waveData;
    }  
    
    /** sample rate of original wave file, this property is only available after loadWaveFromByteArray() or saveWaveAsByteArray(). */  
    private function get_waveDataSampleRate() : Float{
        return _waveDataSampleRate;
    }  
    
    /** bit rate of original wave file, this property is only available after loadWaveFromByteArray() or saveWaveAsByteArray(). */  
    private function get_waveDataBitRate() : Int{
        return _waveDataBitRate;
    }  
    
    /** channel count of original wave file, this property is only available after loadWaveFromByteArray() or saveWaveAsByteArray(). */  
    private function get_waveDataChannels() : Int{
        return _waveDataChannels;
    }  
    
    /** sample rate of internal samples. */  
    private function get_internalSampleRate() : Float{
        return _sampleRate;
    }  
    
    /** channel count of internal samples. */  
    private function get_internalChannels() : Int{
        return _channels;
    }

    private var _lvfunctions : Array<Array<Float>->Array<Float>->Float->Float->Void>;
    private var _w2vfunctions : Array<ByteArray->Array<Float>->Void>;
    private var _v2wfunctions : Array<Array<Float>->ByteArray->Void>;

    // constructor
    // --------------------------------------------------    
    /** constructor */  
    public function new(channels : Int = 2, sampleRate : Int = 44100, samples : Array<Float> = null)
    {
        super();
        this._channels = channels;
        this._sampleRate = sampleRate;
        this._samples = samples;
        if (this._samples == null) this._samples = new Array<Float>();
        this._cache = new Array<Float>();
        this._cacheSampleRate = 0;
        this._cacheChannels = 0;
        this._outputSampleRate = _sampleRate;
        this._outputChannels = _channels;
        this._outputBitRate = 16;
        this._waveDataChunks = null;
        this._waveData = null;
        this._waveDataFormatID = 1;
        this._waveDataSampleRate = 0;
        this._waveDataBitRate = 0;
        this._waveDataChannels = 0;
        this._extractPosition = 0;
        this._appendPosition = this._samples.length;
        this.sampleType = 0;
        this.baseNote = 69;
        this.beatCount = 0;
        this.timeSignatureDenominator = 4;
        this.timeSignatureNumber = 4;
        this.bpm = 0;
        _lvfunctions = new Array<Array<Float>->Array<Float>->Float->Float->Void>();
        _lvfunctions.push(_lvmmn);
        _lvfunctions.push(_lvsmn);
        _lvfunctions.push(_lvmsn);
        _lvfunctions.push(_lvssn);
        _lvfunctions.push(_lvmml);
        _lvfunctions.push(_lvsml);
        _lvfunctions.push(_lvmsl);
        _lvfunctions.push(_lvssl);

        _w2vfunctions = new Array<ByteArray->Array<Float>->Void>();
        _w2vfunctions.push(_w2v8);
        _w2vfunctions.push(_w2v16);
        _w2vfunctions.push(_w2v24);
        _w2vfunctions.push(_w2v32);

        _v2wfunctions = new Array<Array<Float>->ByteArray->Void>();
        _v2wfunctions.push(_v2w8);
        _v2wfunctions.push(_v2w16);
        _v2wfunctions.push(_v2w24);
        _v2wfunctions.push(_v2w32);
    }

    /** @private */
    override public function toString() : String{
        var str : String = "[object PCMSample : ";
        str += "channels=" + Std.string(_channels);
        str += " / sampleRate=" + Std.string(_sampleRate);
        str += " / sampleLength=" + Std.string(sampleLength);
        str += " / baseNote=" + Std.string(baseNote);
        str += " / beatCount=" + Std.string(beatCount);
        str += " / bpm=" + Std.string(bpm);
        str += " / timeSignature=" + Std.string(timeSignatureNumber) + "/" + Std.string(timeSignatureDenominator);
        str += "]";
        return str;
    }
    
    // operations    
    // --------------------------------------------------    
    /** load sample from Vector.&lt;Number&gt; 
     *  @param src source vector of Number.
     *  @param channels channel count of source.
     *  @param sampleRate sample rate of source.
     *  @param linear exchange sampling rate by linear interpolation, set false to use samples nearest by.
     */  
    public function loadFromVector(src : Array<Float>, srcChannels : Int = 2, srcSampleRate : Float = 44100, linear : Bool = true) : PCMSample{
        _convertSampleRate(src, srcChannels, srcSampleRate, _samples, _channels, _sampleRate, linear);
        return this;
    }

    /** append samples
     *  @param src buffering source. This should be same format as internalSampleRate and internalChannels
     *  @param sampleCount sample count to append. 0 appends all samples.
     *  @param srcOffset position (in samples) start appending from.
     */

    public function appendSamples(src : Array<Float>, sampleCount : Int = 0, srcOffset : Int = 0) : PCMSample{
        clearCache();
        var i : Int = srcOffset * _channels;
        var len : Int = sampleCount * _channels;
        var ptr : Int;
        var ptrMax : Int;
        if ((len == 0) || ((i + len) > src.length)) len = src.length - i;
        ptrMax = _appendPosition + len;
        ptr = _appendPosition;
        while (ptr < ptrMax){
            _samples[ptr] = src[i];
            ptr++;
            i++;
        }
        _appendPosition = ptrMax;
        return this;
    }

    /** append samples from ByteArray float (2ch/44.1kHz), The internal format should be 2ch/44.1kHz.
     *  @param bytes buffering source. The format should be float vector of 2ch/44.1kHz.
     *  @param sampleCount sample count to append. 0 appends all samples.
     */
    public function appendSamplesFromByteArrayFloat(bytes : ByteArray, sampleCount : Int = 0) : PCMSample {
        if (_channels != 2 || _sampleRate != 44100) throw new Error("The internal format should be 2ch/44.1kHz.");
        clearCache();
        var len : Int = (bytes.length - bytes.position) >> 3;
        var ptr : Int;
        var ptrMax : Int;
        if (sampleCount != 0 && len > sampleCount) len = sampleCount;
        ptrMax = _appendPosition + len * 2;
        ptr=_appendPosition;
        while(ptr<ptrMax) {
            _samples[ptr] = bytes.readFloat();
            ptr++;
        }
        _appendPosition = ptrMax;
        return this;
    }

    /** extract to Vector.&lt;Number&gt;
     *  @param dst 
     *  @param length 
     *  @param offset 
     *  @return 
     */  
    public function extract(dst : Array<Float> = null, length : Int = 0, offset : Int = -1) : Array<Float> {
        if (offset == -1) offset = Std.int(_extractPosition);
        if (dst == null) dst = new Array<Float>();
        
        if (length == 0) length = 999999;
        var output : Array<Float> = this.samples;
        var i : Int;
        var imax : Int = length * _outputChannels;
        var j : Int = offset * _outputChannels;
        if (imax + j > output.length) imax = output.length - j;
        i = 0;
        while (i < imax){
            dst[i] = output[j];
            i++;
            j++;
        }
        _extractPosition = j >> (_outputChannels - 1);
        return dst;
    }  
    
    /** clear cache and waveData */  
    public function clearCache() : PCMSample {
        _cache.splice(0,_cache.length);
        _cacheSampleRate = 0;
        _cacheChannels = 0;
        return this;
    }  
    
    /** clear wave data cache */  
    public function clearWaveDataCache() : PCMSample {
        _waveDataChunks = null;
        _waveData = null;
        _waveDataFormatID = 1;
        _waveDataSampleRate = 0;
        _waveDataBitRate = 0;
        _waveDataChannels = 0;
        return this;
    }  
    
    // wave file operations    
    // --------------------------------------------------    
    /** load from wave file byteArray.
     *  @param waveFile ByteArray of wave file.
     */  
    public function loadWaveFromByteArray(waveFile : ByteArray) : PCMSample {
        var bae : ByteArray = new ByteArray();
        bae.readBytes(waveFile, 0, waveFile.length);

        var content : ByteArray = new ByteArray();
        var fileSize : Int;
        var header : Dynamic;
        var chunkBAE : ByteArray;
        var sliceCount : Int;
        var i : Int;
        var pos : Int;
        
        bae.endian = LITTLE_ENDIAN;
        bae.position = 0;
        header = ByteArrayExt.readChunk(bae, content);
        if (header.chunkID != "RIFF" || header.listType != "WAVE")
            dispatchEvent(new ErrorEvent("Not good wave file"))
        else {
            fileSize = header.length;
            _waveDataChunks = ByteArrayExt.readAllChunks(content);
            if (!((Lambda.has(_waveDataChunks, "fmt ")) && (Lambda.has(_waveDataChunks, "data"))))
                dispatchEvent(new ErrorEvent("Not good wave file"))
            else {
                chunkBAE = Reflect.field(_waveDataChunks, "fmt ");
                _waveDataFormatID = chunkBAE.readShort();
                _waveDataChannels = chunkBAE.readShort();
                _waveDataSampleRate = chunkBAE.readInt();
                chunkBAE.readInt();  // no ckeck for bytesPerSecond = _sampleRate*bytesPerSample
                chunkBAE.readShort();  // no ckeck for bytesPerSample = _bitRate*_channels/8
                _waveDataBitRate = chunkBAE.readShort();
                _waveData = Reflect.field(_waveDataChunks, "data");
                if (Lambda.has(_waveDataChunks, basicInfoChunkID)) {
                    chunkBAE = Reflect.field(_waveDataChunks, basicInfoChunkID);
                    sampleType = chunkBAE.readInt();
                    baseNote = chunkBAE.readShort();
                    chunkBAE.readShort(); // _unknown1 = 0x8000
                    chunkBAE.readInt(); // _unknown2 = 0
                    beatCount = chunkBAE.readInt();
                    timeSignatureDenominator = chunkBAE.readShort();
                    timeSignatureNumber = chunkBAE.readShort();
                    bpm = chunkBAE.readFloat();
                }

                _updateSampleFromWaveData();
                dispatchEvent(new Event(Event.COMPLETE));
            }
        }

        return this;
    }

    /** save wave file as byteArray.
     *  @return waveFile ByteArray of wave file.
     */
    public function saveWaveAsByteArray() : ByteArray {
        var bytesPerSample : Int = (_outputBitRate * _outputChannels) >> 3;
        var waveFile : ByteArray = new ByteArray();
        var content : ByteArray = new ByteArray();
        var fmt : ByteArray = new ByteArray();  
        
        // convert sampling rate, channels and bitrate  
        if (_waveDataChannels != _outputChannels || _waveDataSampleRate != _outputSampleRate || _waveDataBitRate != _outputBitRate) {
            _updateWaveDataFromSamples();
        }  
        // write wave file  
        fmt.endian = LITTLE_ENDIAN;
        fmt.writeShort(1);
        fmt.writeShort(_outputChannels);
        fmt.writeInt(Std.int(_outputSampleRate));
        fmt.writeInt(Std.int(_outputSampleRate * bytesPerSample));
        fmt.writeShort(bytesPerSample);
        fmt.writeShort(_outputBitRate);

        content.endian = LITTLE_ENDIAN;
        ByteArrayExt.writeChunk(content, "fmt ", fmt);
        ByteArrayExt.writeChunk(content, "data", _waveData);

        waveFile.endian = LITTLE_ENDIAN;
        ByteArrayExt.writeChunk(waveFile, "RIFF", content, "WAVE");

        return waveFile;
    }

    // utilities
    // --------------------------------------------------
    /** Try to read mysterious "strc" chunk.
     *  @param strcChunk strc chunk data.
     *  @return positions
     */
    public static function readSTRCChunk(strcChunk : ByteArray) : Array<Dynamic> {
        if (strcChunk == null) return null;
        var i : Int;
        var imax : Int;
        var positions : Array<Dynamic> = [];
        strcChunk.readInt(); // always 28
        imax = strcChunk.readInt();
        strcChunk.readInt();  // either 25 (0x19) or 65 (0x41)
        strcChunk.readInt();  // either 10 (0x0A) or 5 (0x05) linked to prev data ?
        strcChunk.readInt();  // always 1 (0x01)
        strcChunk.readInt();  // either 0, 1 or 10
        strcChunk.readInt();  // have seen values 2,3,4 and 5

        for (i in 0...imax) {
            strcChunk.readInt();  // either 0 or 2
            strcChunk.readInt();  // random?
            positions.push(strcChunk.readInt());
            strcChunk.readInt();  // sample position of this slice
            strcChunk.readInt();
            strcChunk.readInt();  // sp2?
            strcChunk.readInt();  // data3
            strcChunk.readInt();
        }

        return positions;
    }

    // privates
    // --------------------------------------------------    
    // convert sampling rate and channel count  
    private function _convertSampleRate(src : Array<Float>, srcch : Int, srcsr : Float, dst : Array<Float>, dstch : Int, dstsr : Float, linear : Bool) : Void {
        var flag : Int;
        var dstStep : Float = srcsr / dstsr;
        if (dstStep == 1) linear = false;
        //dst.length = Std.int(src.length * dstch * dstsr / (srcch * srcsr));
        //trace("convertSampleRate:", srcch, srcsr, src.length, dstch, dstsr, dst.length);
        flag = ((srcch == 2)) ? 1 : 0;
        flag |= ((dstch == 2)) ? 2 : 0;
        flag |= ((linear)) ? 4 : 0;
        _lvfunctions[flag](src, dst, dstStep, 0);
    }

    private function _lvmmn(src : Array<Float>, dst : Array<Float>, step : Float, ptr : Float) : Void {
        var i : Int = 0;
        var imax : Int = dst.length;
        var iptr : Int;i = 0;
        while (i < imax) {
            iptr = Math.floor(ptr);
            dst[i] = src[iptr];
            i++;
            ptr += step;
        }
    }

    private function _lvmsn(src : Array<Float>, dst : Array<Float>, step : Float, ptr : Float) : Void{
        var i : Int = 0;
        var imax : Int = dst.length;
        var iptr : Int;i = 0;
        while (i < imax) {
            iptr = Math.floor(ptr);
            dst[i] = src[iptr];
            i++;
            dst[i] = src[iptr];
            i++;
            ptr += step;
        }
    }

    private function _lvsmn(src : Array<Float>, dst : Array<Float>, step : Float, ptr : Float) : Void {
        var i : Int = 0;
        var imax : Int = dst.length;
        var iptr : Int;
        var n : Float;i = 0;
        while (i < imax) {
            iptr = (Math.floor(ptr)) * 2;
            n = src[iptr];
            iptr++;
            n += src[iptr];
            dst[i] = n * 0.5;
            i++;
            ptr += step;
        }
    }

    private function _lvssn(src : Array<Float>, dst : Array<Float>, step : Float, ptr : Float) : Void {
        var i : Int = 0;
        var imax : Int = dst.length;
        var iptr : Int;

        i = 0;
        while (i < imax) {
            iptr = (Math.floor(ptr)) * 2;
            dst[i] = src[iptr];
            iptr++;
            i++;
            dst[i] = src[iptr];
            i++;
            ptr += step;
        }
    }

    private function _lvmml(src : Array<Float>, dst : Array<Float>, step : Float, ptr : Float) : Void {
        var i : Int = 0;
        var imax : Int = dst.length - 1;
        var istep : Float = 1 / step;
        var iptr0 : Int;
        var iptr1 : Int = Math.floor(ptr);
        var t : Float;

        for (i in 0...imax) {
            iptr0 = iptr1;
            t = (ptr - iptr0) * istep;
            iptr1 = Math.floor(ptr += step);
            dst[i] = src[iptr0] * (1 - t) + src[iptr1] * t;
        }

        dst[imax] = src[iptr1];
    }

    private function _lvmsl(src : Array<Float>, dst : Array<Float>, step : Float, ptr : Float) : Void {
        var i : Int = 0;
        var imax : Int = dst.length - 2;
        var istep : Float = 1 / step;
        var iptr0 : Int;
        var iptr1 : Int = Math.floor(ptr);
        var t : Float;
        var n : Float;

        i = 0;
        while (i < imax) {
            iptr0 = iptr1;
            t = (ptr - iptr0) * istep;
            iptr1 = Math.floor(ptr += step);
            n = src[iptr0] * (1 - t) + src[iptr1] * t;
            dst[i] = n;i++;
            dst[i] = n;
            i++;
        }

        dst[imax] = src[iptr1];
        dst[imax + 1] = src[iptr1];
    }

    private function _lvsml(src : Array<Float>, dst : Array<Float>, step : Float, ptr : Float) : Void{
        var i : Int = 0;
        var imax : Int = dst.length - 1;
        var istep : Float = 0.5 / step;
        var iptr0 : Int;
        var iptr1 : Int = Math.floor(ptr);
        var t : Float;
        var n : Float;
        var pl0 : Int;
        var pl1 : Int = 0;

        for (i in 0...imax) {
            iptr0 = iptr1;
            t = (ptr - iptr0) * istep;
            iptr1 = Math.floor(ptr += step);
            pl0 = iptr0 * 2;
            pl1 = iptr1 * 2;
            n = src[pl0] * (0.5 - t) + src[pl1] * t;
            pl0++;
            pl1++;
            n += src[pl0] * (0.5 - t) + src[pl1] * t;
            dst[i] = n;
        }

        dst[imax] = (src[pl1] + src[pl1 - 1]) * 0.5;
    }

    private function _lvssl(src : Array<Float>, dst : Array<Float>, step : Float, ptr : Float) : Void {
        var i : Int = 0;
        var imax : Int = dst.length - 2;
        var istep : Float = 1 / step;
        var iptr0 : Int;
        var iptr1 : Int = Math.floor(ptr);
        var t : Float;
        var n : Float;
        var pl0 : Int;
        var pl1 : Int = 0;

        i=0;
        while (i < imax) {
            iptr0 = iptr1;
            t = (ptr - iptr0) * istep;
            iptr1 = Math.floor(ptr += step);
            pl0 = iptr0 * 2;
            pl1 = iptr1 * 2;
            dst[i] = src[pl0] * (1 - t) + src[pl1] * t;
            pl0++;
            pl1++;
            i++;
            dst[i] = src[pl0] * (1 - t) + src[pl1] * t;
            i++;
        }

        dst[imax] = src[pl1 - 1];
        dst[imax + 1] = src[pl1];
    }

    // update samples from wave data
    private function _updateSampleFromWaveData() : Void {
      //trace("_updateSampleFromWaveData");
      var byteRate : Int = _waveDataBitRate >> 3;
        if (_waveDataChannels == _channels && _waveDataSampleRate == _sampleRate) {
            _w2vfunctions[byteRate - 1](_waveData, _samples);
        }
        else {
            _cacheChannels = _waveDataChannels;
            _cacheSampleRate = _waveDataSampleRate;
            _w2vfunctions[byteRate - 1](_waveData, _cache);
            _convertSampleRate(_cache, _cacheChannels, _cacheSampleRate, _samples, _channels, _sampleRate, true);
            clearCache();
        }
    }

    // convert wave to vector
    private function _w2v8(wav : ByteArray, dst : Array<Float>) : Void {
        var unq : Float = 1 / (1 << (_waveDataBitRate - 1));
        var imax : Int = dst.length;
        for (i in 0...imax) {
            dst[i] = (wav.readUnsignedByte() - 128) * unq;
        }
    }

    private function _w2v16(wav : ByteArray, dst : Array<Float>) : Void {
        var unq : Float = 1 / (1 << (_waveDataBitRate - 1));
        var imax : Int = dst.length;
        for (i in 0...imax) {
            dst[i] = wav.readShort() * unq;
        }
    }

    private function _w2v24(wav : ByteArray, dst : Array<Float>) : Void {
        var unq : Float = 1 / (1 << (_waveDataBitRate - 1));
        var imax : Int = dst.length;
        for (i in 0...imax) {
            dst[i] = (_waveData.readByte() + (_waveData.readShort() << 8)) * unq;
        }
    }

    private function _w2v32(wav : ByteArray, dst : Array<Float>) : Void {
        var unq : Float = 1 / (1 << (_waveDataBitRate - 1));
        var imax : Int = dst.length;
        for (i in 0...imax) {
            dst[i] = _waveData.readInt() * unq;
        }
    }

    // convert raw data to samples
    private function _updateWaveDataFromSamples() : Void {
        //trace("_updateWaveDataFromSamples");
        var byteRate : Int = _outputBitRate >> 3;
        var output : Array<Float> = this.samples;

        if (_waveData == null) _waveData = new ByteArray();
        _waveDataSampleRate = _outputSampleRate;
        _waveDataBitRate = _outputBitRate;
        _waveDataChannels = _outputChannels;

        // initialize
        _waveData.clear();
        _waveData.position = 0;

        // convert
        _v2wfunctions[byteRate - 1](output, _waveData);
    }

    // convert vector tp wave
    private function _v2w8(src : Array<Float>, wav : ByteArray) : Void {
        var qn : Float = (1 << (_waveDataBitRate - 1)) - 1;
        var imax : Int = src.length;
        for (i in 0...imax) {
            wav.writeByte(Std.int(src[i] * qn + 128));
        }
    }

    private function _v2w16(src : Array<Float>, wav : ByteArray) : Void {
        var qn : Float = (1 << (_waveDataBitRate - 1)) - 1;
        var imax : Int = src.length;
        for (i in 0...imax) {
            wav.writeShort(Std.int(src[i] * qn));
        }
    }

    private function _v2w24(src : Array<Float>, wav : ByteArray) : Void {
        var n : Float;
        var qn : Float = (1 << (_waveDataBitRate - 1)) - 1;
        var imax : Int = src.length;

        for (i in 0...imax) {
            n = src[i] * qn;
            wav.writeByte(Std.int(n));
            wav.writeShort(Std.int(n) >> 8);
        }
    }

    private function _v2w32(src : Array<Float>, wav : ByteArray) : Void {
        var qn : Float = (1 << (_waveDataBitRate - 1)) - 1;
        var imax : Int = src.length;
        for (i in 0...imax) {
            wav.writeInt(Std.int(src[i] * qn));
        }
    }
}