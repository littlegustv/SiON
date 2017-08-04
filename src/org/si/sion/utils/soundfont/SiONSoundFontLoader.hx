//----------------------------------------------------------------------------------------------------
// SiON sound font loader
//  Copyright (c) 2011 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.sion.utils.soundfont;

import openfl.errors.Error;
import openfl.events.*;
import openfl.net.*;
import openfl.media.Sound;
import openfl.display.Loader;
import openfl.system.LoaderContext;
import openfl.utils.ByteArray;
import org.si.sion.*;
import org.si.sion.utils.*;
import org.si.sion.module.*;
import org.si.sion.sequencer.*;
import org.si.utils.ByteArrayExt;

/** Sound font loader. */
class SiONSoundFontLoader extends EventDispatcher
{
    public var bytesLoaded(get, never) : Float;
    public var bytesTotal(get, never) : Float;

    // variables
    //--------------------------------------------------
    /** SiONSoundFont instance. this instance is available after finish loading. */
    public var soundFont : SiONSoundFont;
    
    // loaders
    private var _binloader : URLLoader;
    private var _swfloader : Loader;
    
    
    
    
    // properties
    //--------------------------------------------------
    /** loaded size. */
    private function get_bytesLoaded() : Float
    {
        return ((_swfloader != null)) ? _swfloader.contentLoaderInfo.bytesLoaded : ((_binloader != null)) ? _binloader.bytesLoaded : 0;
    }
    
    
    /** total size. */
    private function get_bytesTotal() : Float
    {
        return ((_swfloader != null)) ? _swfloader.contentLoaderInfo.bytesTotal : ((_binloader != null)) ? _binloader.bytesTotal : 0;
    }
    
    
    
    
    // constructor
    //--------------------------------------------------
    /** constructor */
    public function new()
    {
        super();
        soundFont = null;
        _binloader = null;
        _swfloader = null;
    }
    
    
    
    
    // operations
    //--------------------------------------------------
    /** load sound font from url
     *  @param url requesting url
     *  @param loadAsBinary load soundfont swf as binary and convert to swf.
     *  @param checkPolicyFile check policy file. this argument is ignored when loadAsBinary is true.
     */
    public function load(url : URLRequest, loadAsBinary : Bool = true, checkPolicyFile : Bool = false) : Void
    {
        if (loadAsBinary) {
            _addAllListeners(_binloader = new URLLoader());
            _binloader.dataFormat = URLLoaderDataFormat.BINARY;
            _binloader.load(url);
        }
        else {
            _swfloader = new Loader();
            _addAllListeners(_swfloader.contentLoaderInfo);
            _swfloader.load(url, new LoaderContext(checkPolicyFile));
        }
    }
    
    
    /** load sound font from binary 
     *  @param bytes ByteArray to load from.
     */
    public function loadBytes(bytes : ByteArray) : Bool {
        var success = true;
        trace('fontloader.loadbytes');
        _binloader = null;
        var signature : Int = bytes.readUnsignedInt();
        if (signature == 0x0b535743) {  // swf
            trace('Found a swf');
            _swfloader = new Loader();
            _addAllListeners(_swfloader.contentLoaderInfo);
            _swfloader.loadBytes(bytes);
        }
        else if (signature == 0x04034b50) {  // zip  
            trace('Found a zip');
            _analyzeZip(bytes);
        }
        else {
            var hexSig=StringTools.hex(signature);
            trace('unhandled soundfont type: $signature: 0x$hexSig');
            success = false;
        }
        return success;
    }
    
    
    
    
    // event handling
    //--------------------------------------------------
    private function _addAllListeners(dispatcher : EventDispatcher) : Void
    {
        dispatcher.addEventListener(Event.COMPLETE, _onComplete);
        dispatcher.addEventListener(ProgressEvent.PROGRESS, _onProgress);
        dispatcher.addEventListener(IOErrorEvent.IO_ERROR, _onError);
        dispatcher.addEventListener(SecurityErrorEvent.SECURITY_ERROR, _onError);
    }
    
    
    private function _removeAllListeners() : Void
    {
        var dispatcher : EventDispatcher = _binloader;
        if (dispatcher == null) dispatcher = _swfloader.contentLoaderInfo;
        dispatcher.removeEventListener(Event.COMPLETE, _onComplete);
        dispatcher.removeEventListener(ProgressEvent.PROGRESS, _onProgress);
        dispatcher.removeEventListener(IOErrorEvent.IO_ERROR, _onError);
        dispatcher.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, _onError);
    }
    
    
    private function _onComplete(e : Event) : Void
    {
        trace('SoundFontLoader.onComplete: $e');
        _removeAllListeners();
        if (_binloader != null) {
            trace('Loading bytes from binloader.data');
            loadBytes(_binloader.data);
        }
        else {
            trace('binloader is null');
            _analyze();
            dispatchEvent(e.clone());
        }
    }

    private function _onProgress(e : Event) : Void {
        dispatchEvent(e.clone());
    }

    private function _onError(e : ErrorEvent) : Void {
        _removeAllListeners();dispatchEvent(e.clone());
    }

    
    // internal functions
    //--------------------------------------------------
    private function _analyze() : Void
    {
        trace('SoundFontLoader.analyze. content is ${_swfloader.content}');
        var container : SiONSoundFontContainer = try cast(_swfloader.content, SiONSoundFontContainer) catch(e:Dynamic) null;
        if (container == null) {
            _onError(new IOErrorEvent(IOErrorEvent.IO_ERROR, false, false, "The sound font file is not valid."));
            return;
        }

        // create new sound font instance
        soundFont = new SiONSoundFont(container.sounds);
        
        // parse mml
        var _sw0_ = (container.version);        

        switch (_sw0_)
        {
            case "1":
                _compileSystemCommand(Translator.extractSystemCommand(container.mml));
        }
    }
    
    
    private function _analyzeZip(bytes : ByteArray) : Void
    {
        var bae : ByteArrayExt = new ByteArrayExt(bytes);
        var fileList : Array<ByteArrayExt> = ByteArrayExt.expandZipFile(bae);
        var i : Int;
        var imax : Int = fileList.length;
        var mml : String = null;
        var snd : Sound;
        var file : ByteArrayExt;
        for (i in 0...imax) {
            file = fileList[i];
            if (new EReg('\\.mp3$', "").match(file.name)) {
                snd = new Sound();
                snd.loadCompressedDataFromByteArray(file.bytes, file.bytes.length);
            }
            else if (new EReg('\\.mml$', "").match(file.name)) {
                mml = file.bytes.readUTF();
            }
        }
        _compileSystemCommand(Translator.extractSystemCommand(mml));
    }
    
    
    // compile sound font from system commands
    private function _compileSystemCommand(systemCommands : Array<Dynamic>) : Void
    {
        var i : Int;
        var imax : Int = systemCommands.length;
        var cmd : Dynamic;
        var num : Int = 0;
        var dat : String = null;
        var pfx : String = null;
        var bank : Int;
        var env : SiMMLEnvelopTable;
        var voice : SiONVoice;
        var samplerTable : SiOPMWaveSamplerTable;
        var pcmTable : SiOPMWavePCMTable;

        function __parseToneParam(func : SiOPMChannelParam->String->Void) : Void {
            voice = new SiONVoice();
            func(voice.channelParam, dat);
            if (pfx.length > 0) Translator.parseVoiceSetting(voice, pfx);
            soundFont.fmVoices[num] = voice;
        };

        for (i in 0...imax) {
            cmd = systemCommands[i];
            num = cmd.number;
            dat = cmd.content;
            pfx = cmd.postfix;
            
            var _sw1_ = (cmd.command);            

            switch (_sw1_)
            {
                // tone settings
                case "#@":{
                    __parseToneParam(Translator.parseParam);
                }
                case "#OPM@":{
                    __parseToneParam(Translator.parseOPMParam);
                }
                case "#OPN@":{
                    __parseToneParam(Translator.parseOPNParam);
                }
                case "#OPL@":{
                    __parseToneParam(Translator.parseOPLParam);
                }
                case "#OPX@":{
                    __parseToneParam(Translator.parseOPXParam);
                }
                case "#MA@":{
                    __parseToneParam(Translator.parseMA3Param);
                }
                case "#AL@":{
                    __parseToneParam(Translator.parseALParam);
                }
                
                // parser settings
                case "#FPS":{
                    soundFont.defaultFPS = ((num > 0)) ? num : ((dat == "") ? 60 : Std.parseInt(dat));
                }
                case "#VMODE":{
                    _parseVCommansSubMML(dat);
                }
                
                // tables
                case "#TABLE":{
                    if (num < 0 || num > 254) throw _errorParameterNotValid("#TABLE", Std.string(num));
                    env = new SiMMLEnvelopTable().parseMML(dat, pfx);
                    if (env.head.i == 0) throw _errorParameterNotValid("#TABLE", dat);
                    soundFont.envelopes[num] = env;
                }
                case "#WAV":{
                    if (num < 0 || num > 255) throw _errorParameterNotValid("#WAV", Std.string(num));
                    soundFont.waveTables[num] = _newWaveTable(Translator.parseWAV(dat, pfx));
                }
                case "#WAVB":{
                    if (num < 0 || num > 255) throw _errorParameterNotValid("#WAVB", Std.string(num));
                    soundFont.waveTables[num] = _newWaveTable(Translator.parseWAVB(((dat == "")) ? pfx : dat));
                }
                
                // pcm voice
                case "#SAMPLER":{
                    if (num < 0 || num > 255) throw _errorParameterNotValid("#SAMPLER", Std.string(num));
                    bank = (num >> SiOPMTable.NOTE_BITS) & (SiOPMTable.SAMPLER_TABLE_MAX - 1);
                    num &= (SiOPMTable.NOTE_TABLE_SIZE - 1);
                    if (soundFont.samplerTables[bank] == null) soundFont.samplerTables[bank] = new SiOPMWaveSamplerTable();
                    samplerTable = soundFont.samplerTables[bank];
                    if (!Translator.parseSamplerWave(samplerTable, num, dat, soundFont.sounds))
                        _errorParameterNotValid("#SAMPLER", Std.string(num));
                }
                case "#PCMWAVE":{
                    if (num < 0 || num > 255) throw _errorParameterNotValid("#PCMWAVE", Std.string(num));
                    if (soundFont.pcmVoices[num] == null) soundFont.pcmVoices[num] = new SiONVoice();
                    voice = soundFont.pcmVoices[num];
                    if (!(Std.is(voice.waveData, SiOPMWavePCMTable))) voice.waveData = new SiOPMWavePCMTable();
                    pcmTable = try cast(voice.waveData, SiOPMWavePCMTable) catch(e:Dynamic) null;
                    if (!Translator.parsePCMWave(pcmTable, dat, soundFont.sounds)) _errorParameterNotValid("#PCMWAVE", Std.string(num));
                }
                case "#PCMVOICE":{
                    if (num < 0 || num > 255) throw _errorParameterNotValid("#PCMVOICE", Std.string(num));
                    if (soundFont.pcmVoices[num] == null) soundFont.pcmVoices[num] = new SiONVoice();
                    voice = soundFont.pcmVoices[num];
                    if (!Translator.parsePCMVoice(voice, dat, pfx, soundFont.envelopes)) _errorParameterNotValid("#PCMVOICE", Std.string(num));
                }
                default:
            }
        }
    }
    
    
    // Parse inside of #VMODE{...}
    private function _parseVCommansSubMML(dat : String) : Void
    {
        var tcmdrex : EReg = new EReg('(n88|mdx|psg|mck|tss|%[xv])(\\d*)(\\s*,?\\s*(\\d?))', "g");
        var res : Dynamic;
        var num : Float;
        var i : Int;
        while (tcmdrex.match(dat)) {
            switch (Std.string(tcmdrex.matched(1))) {
                case "%v":
                    i = Std.parseInt(tcmdrex.matched(2));
                    soundFont.defaultVelocityMode = ((i >= 0 && i < SiOPMTable.VM_MAX)) ? i : 0;
                    i = ((tcmdrex.matched(4) != "")) ? Std.parseInt(tcmdrex.matched(4)) : 4;
                    soundFont.defaultVCommandShift = ((i >= 0 && i < 8)) ? i : 0;
                case "%x":
                    i = Std.parseInt(tcmdrex.matched(2));
                    soundFont.defaultExpressionMode = ((i >= 0 && i < SiOPMTable.VM_MAX)) ? i : 0;case "n88", "mdx":
                    soundFont.defaultVelocityMode = SiOPMTable.VM_DR32DB;
                    soundFont.defaultExpressionMode = SiOPMTable.VM_DR48DB;
                case "psg":
                    soundFont.defaultVelocityMode = SiOPMTable.VM_DR48DB;
                    soundFont.defaultExpressionMode = SiOPMTable.VM_DR48DB;
                default:  // mck/tss  
                    soundFont.defaultVelocityMode = SiOPMTable.VM_LINEAR;
                    soundFont.defaultExpressionMode = SiOPMTable.VM_LINEAR;
            }
            
            dat=tcmdrex.matchedRight();
        }
    }
    
    
    // Set wave table data refered by %4
    private function _newWaveTable(data : Array<Float>) : SiOPMWaveTable
    {
        var i : Int;
        var imax : Int = data.length;
        var table : Array<Int> = new Array<Int>();
        for (i in 0...imax) {
            table[i] = SiOPMTable.calcLogTableIndex(data[i]);
        }
        return SiOPMWaveTable.alloc(table);
    }
    
    
    private function _errorParameterNotValid(cmd : String, param : String) : Error
    {
        return new Error("SiMMLSequencer error : Parameter not valid. '" + param + "' in " + cmd);
    }
}


