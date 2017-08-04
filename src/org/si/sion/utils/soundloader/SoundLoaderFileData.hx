//----------------------------------------------------------------------------------------------------
// File Data class for SoundLoader
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------


package org.si.sion.utils.soundloader;

import openfl.net.*;
import openfl.media.*;
import openfl.utils.*;
import openfl.system.*;
import openfl.events.*;
import openfl.display.*;
import org.si.sion.module.ISiOPMWaveInterface;
import org.si.sion.module.SiOPMWavePCMData;
import org.si.sion.module.SiOPMWaveSamplerData;
import org.si.sion.midi.SMFData;
import org.si.utils.ByteArrayExt;
import org.si.sion.utils.soundfont.*;
import org.si.sion.utils.SoundClass;
import org.si.sion.utils.PCMSample;


// Dispatching events
/** @eventType flash.events.Event.COMPLETE */
@:meta(Event(name="complete",type="flash.events.Event"))

/** @eventType flash.events.ErrorEvent.ERROR */
@:meta(Event(name="error",type="flash.events.ErrorEvent"))

/** @eventType  flash.events.ProgressEvent.PROGRESS */
@:meta(Event(name="progress",type="flash.events.ProgressEvent"))



/** File Data class for SoundLoader */
class SoundLoaderFileData extends EventDispatcher
{
    public var dataID(get, never) : String;
    public var data(get, never) : Dynamic;
    public var urlString(get, never) : String;
    public var type(get, never) : String;
    public var bytesLoaded(get, never) : Int;
    public var bytesTotal(get, never) : Int;

    // variables
    //----------------------------------------
    /** @private type converting table */
    static public var _ext2typeTable:Map<String, String> = [
        "mp3" => "mp3",
        "wav" => "wav",
        "mp3bin" => "mp3bin",
        "mid" => "mid",
        "smf" => "mid",
        "swf" => "img",
        "png" => "img",
        "gif" => "img",
        "jpg" => "img",
        "img" => "img",
        "bin" => "bin",
        "txt" => "txt",
        "var" => "var",
        "ssf" => "ssf",
        "ssfpng" => "ssfpng",
        "b2snd" => "b2snd",
        "b2img" => "b2img"
    ];
    
    private var _dataID : String;
    private var _content : Dynamic;
    private var _urlRequest : URLRequest;
    private var _type : String;
    private var _checkPolicyFile : Bool;
    private var _bytesLoaded : Int;
    private var _bytesTotal : Int;
    private var _loader : Loader;
    private var _sound : Sound;
    private var _urlLoader : URLLoader;
    private var _fontLoader : SiONSoundFontLoader;
    private var _byteArray : ByteArray;
    private var _soundLoader : SoundLoader;
    

    // properties
    //----------------------------------------
    /** data id */
    private function get_dataID() : String {
        return _dataID;
    }

    /** loaded data */
    private function get_data() : Dynamic {
        return _content;
    }

    /** url string */
    private function get_urlString() : String {
        return ((_urlRequest != null)) ? _urlRequest.url : null;
    }

    /** data type */
    private function get_type() : String {
        return _type;
    }

    /** loaded bytes */
    private function get_bytesLoaded() : Int {
        return _bytesLoaded;
    }

    /** total bytes */
    private function get_bytesTotal() : Int {
        return _bytesTotal;
    }
    
    // functions
    //----------------------------------------
    /** @private */
    public function new(soundLoader : SoundLoader, id : String, urlRequest : URLRequest, byteArray : ByteArray, ext : String, checkPolicyFile : Bool)
    {
        super();
        trace('SoundLoaderFileData("$id")');
        this._dataID = id;
        this._soundLoader = soundLoader;
        this._urlRequest = urlRequest;
        this._type = _ext2typeTable[ext];
        this._checkPolicyFile = checkPolicyFile;
        this._bytesLoaded = 0;
        this._bytesTotal = 0;
        this._content = null;
        this._sound = null;
        this._loader = null;
        this._urlLoader = null;
        this._byteArray = byteArray;
    }
    

    // private functions
    //----------------------------------------
    /** @private */
    @:allow(org.si.sion.utils.soundloader)
    private function load() : Bool
    {
        trace('InSoundLoaderFileData.load');
        // already loaded
        if (_content != null) {
            return false;
        }
        
        switch (_type)
        {
            case "mp3":
                _addAllListeners(_sound = new Sound());
                _sound.load(_urlRequest, new SoundLoaderContext(1000, _checkPolicyFile));
            case "img", "ssfpng":
                trace('Loading an image...');
                _loader = new Loader();
                trace('Created a new loader');
                _addAllListeners(_loader.contentLoaderInfo);
                trace('Added a listener');
                _loader.load(_urlRequest, new LoaderContext(_checkPolicyFile));
                trace('Called load on $_urlRequest .');
            case "txt":
                _addAllListeners(_urlLoader = new URLLoader());
                _urlLoader.dataFormat = URLLoaderDataFormat.TEXT;
                _urlLoader.load(_urlRequest);
            case "mp3bin", "bin", "wav", "mid":
                _addAllListeners(_urlLoader = new URLLoader());
                _urlLoader.dataFormat = URLLoaderDataFormat.BINARY;
                _urlLoader.load(_urlRequest);
            case "var":
                _addAllListeners(_urlLoader = new URLLoader());
                _urlLoader.dataFormat = URLLoaderDataFormat.VARIABLES;
                _urlLoader.load(_urlRequest);
            case "ssf":
                _addAllListeners(_fontLoader = new SiONSoundFontLoader());
                _fontLoader.load(_urlRequest);
            case "b2snd":
                SoundClass.loadMP3FromByteArray(_byteArray, __loadMP3FromByteArray_onComplete);
            case "b2img":
                _loader = new Loader();
                _addAllListeners(_loader.contentLoaderInfo);
                _loader.loadBytes(_byteArray);
        }
        
        return true;
    }
    
    
    /** @private */
    @:allow(org.si.sion.utils.soundloader)
    private function listenLoadingStatus(target : Dynamic) : Bool
    {
        _sound = try cast(target, Sound) catch(e:Dynamic) null;
        _loader = try cast(target, Loader) catch(e:Dynamic) null;
        _urlLoader = try cast(target, URLLoader) catch(e:Dynamic) null;
        target = _sound;
        if (target == null) target = _urlLoader;
        if (target == null && _loader != null) {
            target = _loader.contentLoaderInfo;
        }
        if (target != null) {
            if (target.bytesTotal != 0 && target.bytesTotal == target.bytesLoaded) {
                _postProcess();
            }
            else {
                _addAllListeners(target);
            }
            return true;
        }
        return false;
    }
    
    
    private function _addAllListeners(dispatcher : EventDispatcher) : Void
    {
        dispatcher.addEventListener(Event.COMPLETE, _onComplete, false, _soundLoader._eventPriority);
        dispatcher.addEventListener(ProgressEvent.PROGRESS, _onProgress, false, _soundLoader._eventPriority);
        dispatcher.addEventListener(IOErrorEvent.IO_ERROR, _onError, false, _soundLoader._eventPriority);
        dispatcher.addEventListener(SecurityErrorEvent.SECURITY_ERROR, _onError, false, _soundLoader._eventPriority);
    }
    
    
    private function _removeAllListeners() : Void
    {
        var dispatcher : EventDispatcher = _sound;
        if (dispatcher == null) dispatcher = _urlLoader;
        if (dispatcher == null) dispatcher = _fontLoader;
        if (dispatcher == null) dispatcher = _loader.contentLoaderInfo;
        dispatcher.removeEventListener(Event.COMPLETE, _onComplete);
        dispatcher.removeEventListener(ProgressEvent.PROGRESS, _onProgress);
        dispatcher.removeEventListener(IOErrorEvent.IO_ERROR, _onError);
        dispatcher.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, _onError);
    }
    
    
    private function _onProgress(e : ProgressEvent) : Void
    {
        dispatchEvent(e.clone());
        _soundLoader._onProgress(this, Std.int(e.bytesLoaded - _bytesLoaded), Std.int(e.bytesTotal - _bytesTotal));
        _bytesLoaded = Std.int(e.bytesLoaded);
        _bytesTotal = Std.int(e.bytesTotal);
    }
    
    
    private function _onComplete(e : Event) : Void
    {
        var loader : URLLoader = cast(e.target, URLLoader);

        trace('SoundLoaderFileData.onComplete');
        _removeAllListeners();
        _soundLoader._onProgress(this, Std.int(loader.bytesLoaded - _bytesLoaded), Std.int(loader.bytesTotal - _bytesTotal));
        _bytesLoaded = loader.bytesLoaded;
        _bytesTotal = loader.bytesTotal;
        _postProcess();
    }
    
    
    private function _postProcess() : Void
    {
        var currentBICID : String;
        var pcmSample : PCMSample;
        var smfData : SMFData;
        
        switch (_type)
        {
            case "mp3":
                _content = _sound;
                _soundLoader._onComplete(this);
            case "wav":
                currentBICID = PCMSample.basicInfoChunkID;
                PCMSample.basicInfoChunkID = "acid";
                pcmSample = new PCMSample().loadWaveFromByteArray(_urlLoader.data);
                PCMSample.basicInfoChunkID = currentBICID;
                _content = pcmSample;
                _soundLoader._onComplete(this);
            case "mid":
                smfData = new SMFData().loadBytes(_urlLoader.data);
                _content = smfData;
                _soundLoader._onComplete(this);
            case "mp3bin":
                SoundClass.loadMP3FromByteArray(_urlLoader.data, __loadMP3FromByteArray_onComplete);
            case "ssf":
                _content = _fontLoader.soundFont;
                _soundLoader._onComplete(this);
            case "ssfpng":
                {
                    trace('SoundLoaderFileData.postProcess - ssfpng');
                    var bitmapSound : Bitmap;
                    try {
                        bitmapSound = cast((_loader.content), Bitmap);
                        trace('cast bitmapsound');
                    }
                    catch (e : Dynamic) {
                        trace('failed to cast');
                        bitmapSound = null;
                    }
                    trace('converting bitmap to soundfont');
                    _convertBitmapDataToSoundFont(bitmapSound.bitmapData);
                }
            case "img", "b2img":
                _content = _loader.content;
                _soundLoader._onComplete(this);
            case "txt", "bin", "var":
                _content = _urlLoader.data;
                _soundLoader._onComplete(this);
        }
    }
    
    
    private function _onError(e : ErrorEvent) : Void
    {
        _removeAllListeners();
        __errorCallback(e);
    }
    
    
    private function __loadMP3FromByteArray_onComplete(sound : Sound) : Void
    {
        _content = sound;
        _soundLoader._onComplete(this);
    }
    
    
    private function _convertBitmapDataToSoundFont(bitmap : BitmapData) : Void
    {
        var bitmap2bytes : ByteArray = new ByteArray();  // convert BitmapData to ByteArray
        trace('in convert');
        _loader = null;
        _fontLoader = new SiONSoundFontLoader();  // convert ByteArray to SWF and SWF to soundList  
        _fontLoader.addEventListener(Event.COMPLETE, __convertB2SF_onComplete);
        _fontLoader.addEventListener(IOErrorEvent.IO_ERROR, __errorCallback);
        trace('Calling loadbytes');
        var dataBytes = ByteArrayExt.fromBitmapData(new ByteArray(), bitmap);
        var success = _fontLoader.loadBytes(dataBytes);
        if (!success)
        {
            _soundLoader._onError(this, "Failed to convert the data");
        }
        trace('loadbytes returned');
    }
    
    
    private function __convertB2SF_onComplete(e : Event) : Void
    {
        trace('convert complete');
        _content = _fontLoader.soundFont;
        trace('calling onComplete');
        _soundLoader._onComplete(this);
    }
    
    
    private function __errorCallback(e : ErrorEvent) : Void
    {
        trace('failed to convert');
        _soundLoader._onError(this, Std.string(e));
    }
}



