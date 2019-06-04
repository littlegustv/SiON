//----------------------------------------------------------------------------------------------------
// The SiMMLSequencer operates SiOPMModule by MML.
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.sion.sequencer;

import openfl.errors.Error;
import openfl.system.System;
import org.si.utils.SLLint;
import org.si.sion.sequencer.base.MMLData;
import org.si.sion.sequencer.base.MMLExecutorConnector;
import org.si.sion.sequencer.base.MMLSequencer;
import org.si.sion.sequencer.base.MMLEvent;
import org.si.sion.sequencer.base.MMLSequenceGroup;
import org.si.sion.sequencer.base.MMLSequence;
import org.si.sion.sequencer.base.MMLParser;

import org.si.sion.module.SiOPMTable;
import org.si.sion.module.SiOPMModule;
import org.si.sion.module.SiOPMChannelParam;
import org.si.sion.module.SiOPMWaveSamplerTable;
import org.si.sion.module.SiOPMWavePCMTable;
import org.si.sion.utils.Translator;



/** The SiMMLSequencer operates SiOPMModule by MML.
 *  SiMMLSequencer -> SiMMLTrack -> SiOPMChannelFM -> SiOPMOperator. (-> means "operates")
 */
class SiMMLSequencer extends MMLSequencer
{
    public var isReadyToProcess(get, never) : Bool;
    public var title(get, never) : String;
    public var processedSampleCount(get, never) : Int;
    public var isFinished(get, never) : Bool;
    public var isSequenceFinished(get, never) : Bool;
    public var isEnableChangeBPM(get, never) : Bool;
    public var callbackOnParsingSystemCommand(never, set) : SiMMLData->Dynamic->Bool;
    public var streamWritingBeat(get, never) : Int;
    public var streamWritingPositionResidue(get, never) : Int;
    public var currentTrack(get, never) : SiMMLTrack;

    // constants
    //--------------------------------------------------
    private static inline var PARAM_MAX : Int = 16;  // maximum prameter count  
    private static inline var MACRO_SIZE : Int = 26;  // macro size  
    private static inline var DEFAULT_MAX_TRACK_COUNT : Int = 128;  // default maximum limit of track count
    private static inline var INT_MIN_VALUE = -2147483648;
    // variables
    //--------------------------------------------------
    /** SiMMLTrack list */
    public var tracks : Array<SiMMLTrack>;
    
    /** @public maximum limit of track count */
    public var _maxTrackCount : Int;
    
    private var _table : SiMMLTable;  // table instance  
    
    private var _callbackEventNoteOn : SiMMLTrack->Bool = null;  // callback function for event trigger "note on"
    private var _callbackEventNoteOff : SiMMLTrack->Bool = null;  // callback function for event trigger "note off"
    private var _callbackTempoChanged : Int->Bool->Void = null;  // callback function for tempo change event
    private var _callbackTimer : Void->Void = null;  // callback function for timer interruption
    private var _callbackBeat : Int->Int->Void = null;  // callback function for beat event
    private var _callbackParseSysCmd : SiMMLData->Dynamic->Bool = null;  // callback function for parsing system command
    
    private var _module : SiOPMModule;  // Module instance  
    private var _connector : MMLExecutorConnector;  // MMLExecutorConnector  
    private var _currentTrack : SiMMLTrack;  // Current processing track  
    private var _macroStrings : Array<String>;  // Macro strings  
    private var _flagMacroExpanded : Int;  // Expanded macro flag to avoid circular reference  
    private var _envelopEventID : Int;  // Event id of first envelop  
    private var _macroExpandDynamic : Bool;  // Macro expantion mode  
    private var _enableChangeBPM : Bool;  // internal flag enable to change bpm  
    
    private var _p : Array<Int> = new Array<Int>();  // temporary area to get plural parameters  
    private var _internalTableIndex : Int = 0;  // internal table index
    private var _freeTracks : Array<SiMMLTrack>;  // SiMMLTracks free list  
    private var _isSequenceFinished : Bool;  // flag sequence finished  
    
    private var _dummyProcess : Bool;  // play dummy process  
    
    private var _title : String;  // Title of the song.  
    private var _processedSampleCount : Int;  // Processed sample count  
    
    
    
    
    // properties
    //--------------------------------------------------
    /** Is ready to process ? */
    private function get_isReadyToProcess() : Bool{
        return (tracks.length > 0);
    }
    
    /** Song title */
    private function get_title() : String{
        return _title;
    }
    
    /** Processed sample count */
    private function get_processedSampleCount() : Int{
        return _processedSampleCount;
    }
    
    /** Is finish buffering ? */
    private function get_isFinished() : Bool{
        if (!_isSequenceFinished) return false;
        for (trk in tracks){
            if (!trk.isFinished)  return false;
        }
        return true;
    }
    
    /** Is finish executing sequence ? */
    private function get_isSequenceFinished() : Bool {
        return _isSequenceFinished;
    }
    
    /** Is enable to change BPM ? */
    private function get_isEnableChangeBPM() : Bool {
        return _enableChangeBPM;
    }
    
    /** function called back when parse system command. The function type is function(data:SiMMLData, command:*) : Boolean. Return false to append the command to SiONData.systemCommands. */
    private function set_callbackOnParsingSystemCommand(func : SiMMLData->Dynamic->Bool) : SiMMLData->Dynamic->Bool {
        _callbackParseSysCmd = func;
        return func;
    }
    
    /** current writing position (16beat count) in streaming buffer */
    private function get_streamWritingBeat() : Int{
        return Math.floor(_globalBeat16);
    }

    /** current writing position in streaming buffer, always less than length of streaming buffer */
    private function get_streamWritingPositionResidue() : Int{
        return _globalBufferIndex;
    }
    
    /** Current working track */
    private function get_currentTrack() : SiMMLTrack{
        return _currentTrack;
    }
    
    /** SiONTrackEvent.BEAT is called if (beatCount16th &amp; onBeatCallbackFilter) == 0. */
    public function _setBeatCallbackFilter(filter : Int) : Void {
        _onBeatCallbackFilter = filter;
    }
    
    /** @private [sion internal] callback function for timer interruption. */
    public function _setTimerCallback(func : Void->Void) : Void{
        _callbackTimer = func;
    }
    
    /** @private [sion internal] callback function for beat event. changed in SiONDeiver */
    public function _setBeatCallback(func : Int->Int->Void) : Void{
        _callbackBeat = func;
    }
    
    /** @private [sion internal] currently in process to change position */
    private function _isDummyProcess() : Bool{
        return _dummyProcess;
    }
    
    
    // constructor
    //--------------------------------------------------
    /** Create new sequencer. */
    public function new(module : SiOPMModule, eventTriggerOn : SiMMLTrack->Bool, eventTriggerOff : SiMMLTrack->Bool,
                         tempoChanged : Int->Bool->Void)
    {
        super();
        
        var i : Int;

        trace('SiMMLSequencer constructor');

        // initialize
        _table = SiMMLTable.instance;
        _module = module;
        tracks = new Array<SiMMLTrack>();
        _freeTracks = new Array<SiMMLTrack>();
        _processedSampleCount = 0;
        _connector = new MMLExecutorConnector();
        _macroStrings = new Array<String>();
        _callbackEventNoteOn = eventTriggerOn;
        _callbackEventNoteOff = eventTriggerOff;
        _callbackTempoChanged = tempoChanged;
        _currentTrack = null;
        _maxTrackCount = DEFAULT_MAX_TRACK_COUNT;
        _isSequenceFinished = true;
        _dummyProcess = false;

        trace('SMML: 1');

        // pitch
        newMMLEventListener("k", _onDetune);
        trace('SMML: 1a');
        newMMLEventListener("kt", _onKeyTrans);
        newMMLEventListener("!@kr", _onRelativeDetune);
        
        // track setting
        newMMLEventListener("@mask", _onEventMask);
        setMMLEventListener(MMLEvent.QUANT_RATIO, _onQuantRatio);
        setMMLEventListener(MMLEvent.QUANT_COUNT, _onQuantCount);
        
        // volume
        newMMLEventListener("p", _onPan);
        newMMLEventListener("@p", _onFinePan);
        newMMLEventListener("@f", _onFilter);
        newMMLEventListener("x", _onExpression);
        setMMLEventListener(MMLEvent.VOLUME, _onVolume);
        setMMLEventListener(MMLEvent.VOLUME_SHIFT, _onVolumeShift);
        setMMLEventListener(MMLEvent.FINE_VOLUME, _onMasterVolume);
        newMMLEventListener("%v", _onVolumeSetting);
        newMMLEventListener("%x", _onExpressionSetting);
        newMMLEventListener("%f", _onFilterMode);
        
        // channel setting
        newMMLEventListener("@clock", _onClock);
        newMMLEventListener("@al", _onAlgorism);
        newMMLEventListener("@fb", _onFeedback);
        newMMLEventListener("@r", _onRingModulation);
        setMMLEventListener(MMLEvent.MOD_TYPE, _onModuleType);
        setMMLEventListener(MMLEvent.INPUT_PIPE, _onInput);
        setMMLEventListener(MMLEvent.OUTPUT_PIPE, _onOutput);
        newMMLEventListener("%t", _setEventTrigger);
        newMMLEventListener("%e", _dispatchEvent);
        
        // operator setting
        newMMLEventListener("i", _onSlotIndex);
        newMMLEventListener("@rr", _onOpeReleaseRate);
        newMMLEventListener("@tl", _onOpeTotalLevel);
        newMMLEventListener("@ml", _onOpeMultiple);
        newMMLEventListener("@dt", _onOpeDetune);
        newMMLEventListener("@ph", _onOpePhase);
        newMMLEventListener("@fx", _onOpeFixedNote);
        newMMLEventListener("@se", _onOpeSSGEnvelop);
        newMMLEventListener("@er", _onOpeEnvelopReset);
        setMMLEventListener(MMLEvent.MOD_PARAM, _onOpeParameter);
        newMMLEventListener("s", _onSustain);
        
        // modulation
        newMMLEventListener("@lfo", _onLFO);
        newMMLEventListener("mp", _onPitchModulation);
        newMMLEventListener("ma", _onAmplitudeModulation);
        
        // envelop
        newMMLEventListener("@fps", _onEnvelopFPS);
        _envelopEventID =
                newMMLEventListener("@@", _onToneEnv);
        newMMLEventListener("na", _onAmplitudeEnv);
        newMMLEventListener("np", _onPitchEnv);
        newMMLEventListener("nt", _onNoteEnv);
        newMMLEventListener("nf", _onFilterEnv);
        newMMLEventListener("_@@", _onToneReleaseEnv);
        newMMLEventListener("_na", _onAmplitudeReleaseEnv);
        newMMLEventListener("_np", _onPitchReleaseEnv);
        newMMLEventListener("_nt", _onNoteReleaseEnv);
        newMMLEventListener("_nf", _onFilterReleaseEnv);
        newMMLEventListener("!na", _onAmplitudeEnvTSSCP);
        newMMLEventListener("po", _onPortament);
        
        // processing events
        _registerProcessEvent();
        
        setMMLEventListener(MMLEvent.DRIVER_NOTE, _onDriverNoteOn);
        setMMLEventListener(MMLEvent.REGISTER, _onRegisterUpdate);
        
        // set initial values of operators
        _module.initOperatorParam.ar = 63;
        _module.initOperatorParam.dr = 0;
        _module.initOperatorParam.sr = 0;
        _module.initOperatorParam.rr = 28;
        _module.initOperatorParam.sl = 0;
        _module.initOperatorParam.tl = 0;
        _module.initOperatorParam.ksr = 0;
        _module.initOperatorParam.ksl = 0;
        _module.initOperatorParam.fmul = 128;
        _module.initOperatorParam.dt1 = 0;
        _module.initOperatorParam.detune = 0;
        _module.initOperatorParam.ams = 1;
        _module.initOperatorParam.phase = 0;
        _module.initOperatorParam.fixedPitch = 0;
        _module.initOperatorParam.modLevel = 5;
        _module.initOperatorParam.setPGType(SiOPMTable.PG_SQUARE);
        
        // parsers initial settings
        setting.defaultBPM = 120;
        setting.defaultLValue = 4;
        setting.defaultQuantRatio = 6;
        setting.maxQuantRatio = 8;
        setting.defaultOctave = 5;
        setting.maxVolume = 512;
        setting.defaultVolume = 256;
        setting.maxFineVolume = 128;
        setting.defaultFineVolume = 64;
    }
    
    
    
    
    // operation for all tracks
    //--------------------------------------------------
    // Free all tracks.
    private function _freeAllTracks() : Void
    {
        for (trk in tracks)_freeTracks.push(trk);
        tracks.splice(0, tracks.length);
    }
    
    
    /** @private [sion internal] Reset all tracks. */
    public function _resetAllTracks() : Void
    {
        trace('all tracks:', tracks.length);
        for (trk in tracks){
            trace('resetting track');
            trk._reset(0);
            trace('track reset');
            trk.velocity = setting.defaultVolume;
            trk.quantRatio = setting.defaultQuantRatio / setting.maxQuantRatio;
            trk.quantCount = calcSampleCount(setting.defaultQuantCount);
            trk.channel.masterVolume = setting.defaultFineVolume;
        }
        _processedSampleCount = 0;
        _isSequenceFinished = (tracks.length == 0);
    }
    
    
    /** @private [sion internal] force stop */
    public function _stopSequence() : Void
    {
        _isSequenceFinished = true;
    }
    
    
    
    
    // operation for controlable tracks
    //--------------------------------------------------
    /** @private [sion internal] Find active track by internal track ID.
     *  @param internalTrackID internal track ID to find.
     *  @param delay delay value to find the track sounds at same timing. -1 ignores this value.
     *  @return found track instance. Returns null when didnt find.
     */
    public function _findActiveTrack(internalTrackID : Int, delay : Int = -1) : SiMMLTrack
    {
        var result : Array<Dynamic> = [];
        for (trk in tracks){
            if (trk._internalTrackID == internalTrackID && trk.isActive) {
                if (delay == -1)                     return trk;
                var diff : Int = trk.trackStartDelay - delay;
                if (-8 < diff && diff < 8)                     return trk;
            }
        }
        return null;
    }
    
    
    /** @private [sion internal] Get new controlable track.
     *  @param internalTrackID New internal Tracks ID.
     *  @param isDisposable disposable flag
     *  @return Returns null when there are no free tracks.
     */
    public function _newControlableTrack(internalTrackID : Int = 0, isDisposable : Bool = true) : SiMMLTrack
    {
        var i : Int;
        var trk : SiMMLTrack;
        i = tracks.length - 1;
        while (i >= 0){
            trk = tracks[i];
            if (!trk.isActive) {
                return _initializeTrack(trk, internalTrackID, isDisposable);
            }
            i--;
        }
        
        if (tracks.length < _maxTrackCount) {
            trk = _freeTracks.pop();
            if (trk == null) trk = new SiMMLTrack();
            trk._trackNumber = tracks.length;
            tracks.push(trk);
        }
        else {
            trk = _findLowestPriorityTrack();
            if (trk == null)                 return null;
        }
        
        return _initializeTrack(trk, internalTrackID, isDisposable);
    }
    
    
    // initialize track
    private function _initializeTrack(track : SiMMLTrack, internalTrackID : Int, isDisposable : Bool) : SiMMLTrack
    {
        track._initialize(null, 60, (internalTrackID >= 0) ? internalTrackID : 0, _callbackEventNoteOn, _callbackEventNoteOff, isDisposable);
        track._reset(_globalBufferIndex);
        track.channel.masterVolume = setting.defaultFineVolume;
        return track;
    }

    // find lowest priority track
    private function _findLowestPriorityTrack() : SiMMLTrack
    {
        var i : Int;
        var p : Int;
        var index : Int = 0;
        var maxPriority : Int = 0;
        i = tracks.length - 1;
        while (i >= 0) {
            p = tracks[i].priority;
            if (p >= maxPriority) {
                index = i;
                maxPriority = p;
            }
            i--;
        }

        return ((maxPriority == 0)) ? null : tracks[index];
    }

    // compile
    //--------------------------------------------------
    /** Prepare to compile mml string. Calls onBeforeCompile() inside.
     *  @param data Data instance.
     *  @param mml MML String.
     *  @return Returns false when it's not necessary to compile.
     */
    override public function prepareCompile(data : MMLData, mml : String) : Bool
    {
        _freeAllTracks();
        var returnValue = super.prepareCompile(data, mml);
        return returnValue;
    }
    
    
    
    
    // process
    //--------------------------------------------------
    /** @private [sion internal] Prepare to process audio.
     *  @param bufferLength Buffering length of processing samples at once.
     *  @param resetParams Reset all channel parameters.
     */
    override public function _prepareProcess(data : MMLData, sampleRate : Int, bufferLength : Int) : Void
    {
        trace('SiMMLSequencer._prepareProcess($data, $sampleRate, $bufferLength)');
        // initialize all channels
        _freeAllTracks();
        _processedSampleCount = 0;
        _enableChangeBPM = true;

        // call super function (set mmlData/globalSequence/defaultBPM inside)
        super._prepareProcess(data, sampleRate, bufferLength);

        if (mmlData != null) {
            // initialize all sequence tracks
            var trk : SiMMLTrack;
            var seq : MMLSequence = mmlData.sequenceGroup.headSequence;
            var idx : Int = 0;
            var internalTrackID : Int;

            while (seq != null) {
                if (seq.isActive) {
                    trk = _freeTracks.pop();
                    if (trk == null) trk = new SiMMLTrack();
                    internalTrackID = idx | SiMMLTrack.MML_TRACK;
                    tracks[idx] = trk._initialize(seq, mmlData.defaultFPS, internalTrackID, _callbackEventNoteOn, _callbackEventNoteOff, true);
                    tracks[idx]._trackNumber = idx;
                    idx++;
                }
                seq = seq.nextSequence;
            }
        }

        trace('resetting all tracks');
        // reset
        _resetAllTracks();

        trace('done resetting...');
    }
    
    
    /** @private [sion internal] Process all tracks. Calls onProcess() inside. This funciton must be called after prepareProcess(). */
    override public function _process() : Void
    {
        var bufferingLength : Int;
        var len : Int;
        var trk : SiMMLTrack;
        var data : SiMMLData;
        var finished : Bool;

        // prepare buffering
        for (trk in tracks) {
            trk.channel.resetChannelBufferStatus();
        }

        // buffering
        finished = true;
        startGlobalSequence();
        do{
            bufferingLength = executeGlobalSequence();
            _enableChangeBPM = false;
            for (trk in tracks) {
                _currentTrack = trk;
                len = trk._prepareBuffer(bufferingLength);
                _bpm = trk._bpmSetting;
                if (_bpm == null) _bpm = _changableBPM;
                finished = processMMLExecutor(trk.executor, len) && finished;
            }
            _enableChangeBPM = true;
        } while ((!isEndGlobalSequence()));

        _bpm = _changableBPM;
        _currentTrack = null;
        _processedSampleCount += _module.bufferLength;

        _isSequenceFinished = finished;
    }
    
    
    /** Dummy process. This function must be called after prepareProcess().
     *  @param length dumming sample count. [NOTICE] This value is rounded by a buffer length. Not an exact value.
     */
    public function dummyProcess(sampleCount : Int) : Void
    {
        var count : Int;
        var bufCount : Int = Math.floor(sampleCount / _module.bufferLength);
        if (bufCount == 0) return;

          // register dummy processing events  ;
        _dummyProcess = true;
        _registerDummyProcessEvent();
        
        // pseudo processing
        for (count in 0...bufCount) {
            _process();
        }
        
        // register standard processing events
        _dummyProcess = false;
        _registerProcessEvent();
    }
    
    
    
    
    // calculation
    //--------------------------------------------------
    /** calculate length (in sample count).
     *  @param beat16 The beat number in 16th calculating from.
     */
    public function calcSampleLength(beat16 : Float) : Int {
        return Math.floor(beat16 * _bpm.samplePerBeat16);
    }
    
    
    /** calculate delay (in sample count) quantized by beat.
     *  @param sampleOffset Offset in sample count.
     *  @param beat16Offset Offset in 16th beat.
     *  @param quant Quantizing beat in 16th. The 0 sets no quantization, 1 sets quantization by 16th, 4 sets quantization by 4th beat.
     */
    public function calcSampleDelay(sampleOffset : Int = 0, beat16Offset : Float = 0, quant : Float = 0) : Float{
        if (quant == 0) return sampleOffset + beat16Offset * _bpm.samplePerBeat16;
        var iBeats : Int = Math.floor(sampleOffset * _bpm.beat16PerSample + _globalBeat16 + beat16Offset + 0.9999847412109375);  //=65535/65536
        if (quant != 1) iBeats = Math.floor(Math.floor((iBeats + quant - 1) / quant) * quant);
        return (iBeats - _globalBeat16) * _bpm.samplePerBeat16;
    }
    
    
    
    
    //====================================================================================================
    // Internal uses
    //====================================================================================================
    // implements
    //--------------------------------------------------
    /** @private [protected] Preprocess mml string */
    override private function onBeforeCompile(mml : String) : String
    {
        var codeA : Int = "A".charCodeAt(0);
        var codeH : Int = "-".charCodeAt(0);
        var comrex : EReg = new EReg("/\\*.*?\\*/|//.*?[\\r\\n]+", "gms");
        var reprex : EReg = new EReg("!\\[(\\d*)(.*?)(!\\|(.*?))?!\\](\\d*)", "gms");
        var seqrex : EReg = new EReg("[ \\t\\r\\n]*(#([A-Z@\\-]+)\\s*(\\+=|=)?)?([^;{]*({.*?})?[^;]*);", "gms");  //}
        var midrex : EReg = new EReg("([A-Z])?(-([A-Z])?)?", "g");
        var expmml : String;
        var c : Int;
        var i : Int;
        var imax : Int;
        var str1 : String;
        var str2 : String;
        var concat : Bool;
        var startID : Int;
        var endID : Int;

        // reset
        trace("reset");
        _resetParserParameters();

        // remove comments
        trace("remove comments");
        mml += "\n";
        mml = comrex.replace(mml, "");

        // format last
        trace("format last");
        i = mml.length;
        do {
            if (i == 0)
                return null;
            str1 = mml.charAt(--i);
        }  while ((" \t\r\n".indexOf(str1) != -1));

        mml = mml.substring(0, i + 1);
        if (str1 != ";")
            mml += ";";

        // expand macros
        trace("expand macros");
        expmml = "";
        while (seqrex.match(mml)) {
            // normal sequence
            trace("normal sequence");
            if (seqrex.matched(1) == null) {
                expmml += _expandMacro(seqrex.matched(4)) + ";";
            }
            else if (seqrex.matched(3) == null) {
                // system command
                trace("system command");
                if (Std.string(seqrex.matched(2)) == "END") {
                    // #END command
                    trace("#END command");
                    break;
                }
                else if (!_parseSystemCommandBefore(Std.string(seqrex.matched(1)), seqrex.matched(4))) {
                    // parse system command
                    // if the function returns false, parse system command after compiling mml.
                    trace("parse system command");
                    expmml += Std.string(seqrex.matched(0));
                }
            }
            else {
                // macro definition
                trace("macro definition");
                str2 = seqrex.matched(2);
                concat = (seqrex.matched(3) == "+=");
                // parse macro IDs
                trace("parse macro IDs");
                while (midrex.match(str2)) {
                    trace("parse macro IDs 1");
                    if ((midrex.matched(0) == null) || (midrex.matched(0).length == 0)) break;

                    trace("parse macro IDs 2");
                    startID = (midrex.matched(1) != null) ? (midrex.matched(1).charCodeAt(0) - codeA) : 0;
                    endID = (midrex.matched(2) != null) ? (midrex.matched(3) != null ? (midrex.matched(3).charCodeAt(0) - codeA) : MACRO_SIZE - 1) : startID;
                    trace("parse macro IDs 3");
                    for (i in  startID...(endID + 1)) {
                        if (concat) {
                            trace("parse macro IDs 4");
                            _macroStrings[i] += _macroExpandDynamic ? Std.string(seqrex.matched(4)) : _expandMacro(seqrex.matched(4));
                        }
                        else {
                            trace("parse macro IDs 5");
                            _macroStrings[i] = _macroExpandDynamic ? Std.string(seqrex.matched(4)) : _expandMacro(seqrex.matched(4));
                        }
                    }
                    trace("parse macro IDs 6");
                    str2 = midrex.matchedRight();
                }
            }

            // next
            trace("next");
            mml = seqrex.matchedRight();
        }

        // expand repeat
        trace("expand repeat");
        expmml = reprex.map(expmml,
                        function(regex:EReg) : String{
                            imax = ((regex.matched(1).length > 0)) ? (Std.parseInt(regex.matched(1)) - 1) :
                                                                     ((regex.matched(5).length > 0)) ? (Std.parseInt(regex.matched(5)) - 1) : 1;
                            if (imax > 256) imax = 256;
                            str2 = regex.matched(2);
                            if (regex.matched(3) != null) str2 += regex.matched(4);
                            str1 = "";
                            for (i in 0...imax) {
                                str1 += str2;
                            }
                            str1 += regex.matched(2);
                            return str1;
                        }
                        );

        trace("mml, expmml");
        trace(mml); trace(expmml);
        return expmml;
    }
    
    
    /** @private [protected] Postprocess of compile. */
    override private function onAfterCompile(seqGroup : MMLSequenceGroup) : Void
    {
        // parse system command after parsing
        var seq : MMLSequence = seqGroup.headSequence;
        while (seq != null){
            if (seq.isSystemCommand()) {
                // parse system command
                seq = _parseSystemCommandAfter(seqGroup, seq);
            }
            else {
                // normal sequence
                seq = seq.nextSequence;
            }
        }
    }
    
    
    /** @private [protected] Callback when table event was found. */
    override private function onTableParse(prev : MMLEvent, table : String) : Void
    {
        if (prev.id < _envelopEventID || _envelopEventID + 10 < prev.id) throw _errorInternalTable();
        
        var rex : EReg = new EReg('\\{([^}]*)\\}(.*)', "ms");
        rex.match(table);
        var dat : String = rex.matched(1);
        var pfx : String = rex.matched(2);
        var env : SiMMLEnvelopTable = new SiMMLEnvelopTable().parseMML(dat, pfx);
        if (env.head == null) throw _errorParameterNotValid("{..}", dat);
        cast((mmlData), SiMMLData).setEnvelopTable(_internalTableIndex, env);
        prev.data = _internalTableIndex;
        _internalTableIndex--;
    }
    
    
    /** @private [protected] Processing audio */
    override private function onProcess(sampleLength : Int, e : MMLEvent) : Void
    {
        _currentTrack._buffer(sampleLength);
    }
    
    
    /** @private [protected] Callback when the tempo is changed. */
    override private function onTempoChanged(changingRatio : Float) : Void
    {
        for (trk in tracks){
            if (trk._bpmSetting == null) trk.executor._onTempoChanged(changingRatio);
        }
        if (_callbackTempoChanged != null) _callbackTempoChanged(_globalBufferIndex, _dummyProcess);
    }
    
    
    /** @private [protected] Callback when the timer interruption. */
    override private function onTimerInterruption() : Void
    {
        if (!_dummyProcess && _callbackTimer != null)             _callbackTimer();
    }
    
    
    /** @private [protected] Callback on every 16th beats. */
    override private function onBeat(delaySamples : Int, beatCounter : Int) : Void
    {
        if (!_dummyProcess && _callbackBeat != null) _callbackBeat(delaySamples, beatCounter);
    }
    
    
    
    
    // sub routines for parser
    //--------------------------------------------------
    // Reset parser parameters.
    private function _resetParserParameters() : Void
    {
        var i : Int;
        
        // initialize
        _internalTableIndex = 511;
        _title = "";
        setting.octavePolarization = 1;
        setting.volumePolarization = 1;
        setting.defaultQuantRatio = 6;
        setting.maxQuantRatio = 8;
        _macroExpandDynamic = false;
        MMLParser.keySign = "C";
        for (i in 0..._macroStrings.length){
            _macroStrings[i] = "";
        }
    }
    
    
    // Expand macro.
    private function _expandMacro(m : Dynamic, recursive : Bool = false) : String
    {
        if (!recursive)             _flagMacroExpanded = 0;
        if (m == null)             return "";
        var charCodeA : Int = "A".charCodeAt(0);
        return new EReg('([A-Z])(\\(([\\-\\d]+)\\))?', "g").map(m,
                function(regex:EReg) : String{
                    var t : Int = 0;
                    var i : Int;
                    var f : Int;
                    i = Std.string(regex.matched(1)).charCodeAt(0) - charCodeA;
                    f = 1 << i;
                    if (_flagMacroExpanded != 0 && f != 0) throw _errorCircularReference(m);
                    if (_macroStrings[i] != null) {
                        if (regex.matched(2) != null && regex.matched(2).length > 0) {
                            if (regex.matched(3).length > 0) t = Std.parseInt(regex.matched(3));
                            return "!@ns" + Std.string(t) + (((_macroExpandDynamic)) ? _expandMacro(_macroStrings[i], true) : _macroStrings[i]) + "!@ns" + Std.string(-t);
                        }
                        return ((_macroExpandDynamic)) ? _expandMacro(_macroStrings[i], true) : _macroStrings[i];
                    }
                    return "";
                }
                );
    }
    
    
    
    
    // system command parser
    //--------------------------------------------------
    // Parse system command before parsing mml. returns false when it hasnt parsed.
    private function _parseSystemCommandBefore(cmd : String, prm : String) : Bool
    {
        var i : Int;
        var param : SiOPMChannelParam;
        var env : SiMMLEnvelopTable;
        var commandObject : Dynamic;
        
        // separating
        var rex : EReg = new EReg('\\s*(\\d*)\\s*(\\{(.*?)\\})?(.*)', "ms");
        if (!rex.match(prm)) {
            return false;
        }
        
        // abstructing
        var num : Int = Std.parseInt(rex.matched(1));
        var noData : Bool = (rex.matched(2) == null);
        var dat : String = noData ? "" : rex.matched(3);
        var pfx : String = rex.matched(4);  // postfix string


        function __parseToneParam(func : SiOPMChannelParam->String->Void) : Void{
            param = cast(mmlData, SiMMLData)._getSiOPMChannelParam(num);
            func(param, dat);
            if (pfx.length > 0) __parseInitSequence(param, pfx);
        };

        function __setAsCommandObject() : Void{
            commandObject = {
                command : cmd,
                number : num,
                content : dat,
                postfix : pfx
            };

            var simmlData : SiMMLData;
            try {
                simmlData = cast(mmlData, SiMMLData);
            }
            catch (e : Dynamic) {
                simmlData = null;
            }
            if (_callbackParseSysCmd == null || !_callbackParseSysCmd(simmlData, commandObject)) {
                mmlData.systemCommands.push(commandObject);
            }
        };

        // executing
        switch (cmd)
        {
            // tone settings
            case "#@":{__parseToneParam(Translator.parseParam);return true;
            }
            case "#OPM@":{__parseToneParam(Translator.parseOPMParam);return true;
            }
            case "#OPN@":{__parseToneParam(Translator.parseOPNParam);return true;
            }
            case "#OPL@":{__parseToneParam(Translator.parseOPLParam);return true;
            }
            case "#OPX@":{__parseToneParam(Translator.parseOPXParam);return true;
            }
            case "#MA@":{__parseToneParam(Translator.parseMA3Param);return true;
            }
            case "#AL@":{__parseToneParam(Translator.parseALParam);return true;
            }
            
            // parser settings
            case "#TITLE":{mmlData.title = ((noData)) ? pfx : dat;return true;
            }
            case "#FPS":{mmlData.defaultFPS = ((num > 0)) ? num : (noData ? 60 : Std.parseInt(dat));return true;
            }
            case "#SIGN":{MMLParser.keySign = ((noData)) ? pfx : dat;return true;
            }
            case "#MACRO":{
                if (noData)                     dat = pfx;
                if (dat == "dynamic")                     _macroExpandDynamic = true
                else if (dat == "static")                     _macroExpandDynamic = false
                else throw _errorParameterNotValid("#MACRO", dat);
                return true;
            }
            case "#QUANT":{
                if (num > 0) {
                    setting.maxQuantRatio = num;
                    setting.defaultQuantRatio = Math.floor(num * 0.75);
                }
                return true;
            }
            case "#TMODE":{
                _parseTCommansSubMML(dat);
                return true;
            }
            case "#VMODE":{
                _parseVCommansSubMML(dat);
                return true;
            }
            case "#REV":{
                if (noData)                     dat = pfx;
                if (dat == "") {
                    setting.octavePolarization = -1;
                    setting.volumePolarization = -1;
                }
                else 
                if (dat == "octave") {
                    setting.octavePolarization = -1;
                }
                else 
                if (dat == "volume") {
                    setting.volumePolarization = -1;
                }
                else {
                    throw _errorParameterNotValid("#REVERSE", dat);
                }
                return true;
            }
            
            // tables
            case "#TABLE":{
                if (num < 0 || num > 254) throw _errorParameterNotValid("#TABLE", Std.string(num));
                env = new SiMMLEnvelopTable().parseMML(dat, pfx);
                if (env.head.i != 0) throw _errorParameterNotValid("#TABLE", dat);
                cast((mmlData), SiMMLData).setEnvelopTable(num, env);
                return true;
            }
            case "#WAV":{
                if (num < 0 || num > 255) throw _errorParameterNotValid("#WAV", Std.string(num));
                cast((mmlData), SiMMLData).setWaveTable(num, Translator.parseWAV(dat, pfx));
                return true;
            }
            case "#WAVB":{
                if (num < 0 || num > 255) throw _errorParameterNotValid("#WAVB", Std.string(num));
                cast((mmlData), SiMMLData).setWaveTable(num, Translator.parseWAVB(((noData)) ? pfx : dat));
                return true;
            }
            
            // pcm voice
            case "#SAMPLER":{
                if (num < 0 || num > 255) throw _errorParameterNotValid("#SAMPLE", Std.string(num));
                if (!__setSamplerWave(num, dat)) __setAsCommandObject();
                return true;
            }
            case "#PCMWAVE":{
                if (num < 0 || num > 255) throw _errorParameterNotValid("#PCMWAVE", Std.string(num));
                if (!__setPCMWave(num, dat)) __setAsCommandObject();
                return true;
            }
            case "#PCMVOICE":{
                if (num < 0 || num > 255)                     throw _errorParameterNotValid("#PCMVOICE", Std.string(num));
                if (!__setPCMVoice(num, dat, pfx))                     __setAsCommandObject();
                return true;
            }
            
            // system command after parsing
            case "#FM":
                return false;
            case "#WAVEXP", "#PCMB", "#PCMC":
                throw _errorSystemCommand("#" + cmd + " is not supported currently.");
                __setAsCommandObject();
                return true;
            
            // user defined system commands ?
            default:
                __setAsCommandObject();
                return true;
        }
        
        throw _errorUnknown("_parseSystemCommandBefore()");
    }
    
    // Parse inside of #TMODE{...}
    private function _parseTCommansSubMML(dat : String) : Void
    {
        var tcmdrex : EReg = new EReg('(unit|timerb|fps)=?([\\d.]*)', "");
        if (!tcmdrex.match(dat)) return;
        var num : Float;
        num = Std.parseFloat(tcmdrex.matched(2));
        if (Math.isNaN(num))             num = 0;
        switch (tcmdrex.matched(1))
        {
            case "unit":
                mmlData.tcommandMode = MMLData.TCOMMAND_BPM;
                mmlData.tcommandResolution = ((num > 0)) ? 1 / num : 1;
            case "timerb":
                mmlData.tcommandMode = MMLData.TCOMMAND_TIMERB;
                mmlData.tcommandResolution = (((num > 0)) ? num : 4000) * 1.220703125;
            case "fps":
                mmlData.tcommandMode = MMLData.TCOMMAND_FRAME;
                mmlData.tcommandResolution = ((num > 0)) ? num * 60 : 3600;
        }
    }
    
    // Parse inside of #VMODE{...}
    private function _parseVCommansSubMML(dat : String) : Void
    {
        var tcmdrex : EReg = new EReg('(n88|mdx|psg|mck|tss|%[xv])(\\d*)(\\s*,?\\s*(\\d?))', "g");
        var num : Float;
        var i : Int;
        while (tcmdrex.match(dat)){
            switch (tcmdrex.matched(1))
            {
                case "%v":
                    i = Std.parseInt(tcmdrex.matched(2));
                    mmlData.defaultVelocityMode = ((i >= 0 && i < SiOPMTable.VM_MAX)) ? i : 0;
                    i = ((tcmdrex.matched(4) != "")) ? Std.parseInt(tcmdrex.matched(4)) : 4;
                    mmlData.defaultVCommandShift = ((i >= 0 && i < 8)) ? i : 0;
                case "%x":
                    i = Std.parseInt(tcmdrex.matched(2));
                    mmlData.defaultExpressionMode = ((i >= 0 && i < SiOPMTable.VM_MAX)) ? i : 0;case "n88", "mdx":
                    mmlData.defaultVelocityMode = SiOPMTable.VM_DR32DB;
                    mmlData.defaultExpressionMode = SiOPMTable.VM_DR48DB;
                case "psg":
                    mmlData.defaultVelocityMode = SiOPMTable.VM_DR48DB;
                    mmlData.defaultExpressionMode = SiOPMTable.VM_DR48DB;
                default:  // mck/tss  
                    mmlData.defaultVelocityMode = SiOPMTable.VM_LINEAR;
                    mmlData.defaultExpressionMode = SiOPMTable.VM_LINEAR;
            }
        }
    }
    
    // Parse system command after parsing mml.
    private function _parseSystemCommandAfter(seqGroup : MMLSequenceGroup, syscmd : MMLSequence) : MMLSequence
    {
        var letter : String = syscmd.getSystemCommand();
        var rex : EReg = new EReg('#(FM)[{ \\\\t\\\\r\\\\n]*([^}]*)', "");

        // skip system command
        var seq : MMLSequence = syscmd._removeFromChain();
        
        // parse command
        if (rex.match(letter)) {
            var _sw0_ = (rex.matched(1));

            switch (_sw0_)
            {
                case "FM":
                    if (rex.matched(2) == null) throw _errorSystemCommand(letter);
                    _connector.parse(rex.matched(2));
                    seq = _connector.connect(seqGroup, seq);
                default:
                    throw _errorSystemCommand(letter);
            }
        }
        
        return seq.nextSequence;
    }
    
    
    
    
    // system command parser subs
    //--------------------------------------------------
    // parse initializing sequence, called by __splitDataString()
    private function __parseInitSequence(param : SiOPMChannelParam, mml : String) : Void
    {
        var seq : MMLSequence = param.initSequence;
        var prev : MMLEvent;
        var e : MMLEvent;
        
        MMLParser.prepareParse(setting, mml);
        e = MMLParser.parse();
        
        if (e != null && e.next != null) {
            seq._cutout(e);
            prev = seq.headEvent;
            while (prev.next != null){
                e = prev.next;
                // initializing sequence cannot include procssing events
                if (e.length != 0)                     throw _errorInitSequence(mml);

                // initializing sequence cannot include % and @.
                if (e.id == MMLEvent.MOD_TYPE || e.id == MMLEvent.MOD_PARAM) throw _errorInitSequence(mml);

                // parse table event
                if (e.id == MMLEvent.TABLE_EVENT) {
                    callOnTableParse(prev);
                    e = prev;
                }
                prev = e;
            }
        }
    }
    
    
    private function __setSamplerWave(index : Int, dat : String) : Bool{
        if (SiOPMTable.instance.soundReference == null)             return false;
        var bank : Int = (index >> SiOPMTable.NOTE_BITS) & (SiOPMTable.SAMPLER_TABLE_MAX - 1);
        index &= (SiOPMTable.NOTE_TABLE_SIZE - 1);
        var table : SiOPMWaveSamplerTable = cast((mmlData), SiMMLData).samplerTables[bank];
        return Translator.parseSamplerWave(table, index, dat, SiOPMTable.instance.soundReference);
    }
    
    
    private function __setPCMWave(index : Int, dat : String) : Bool{
        if (SiOPMTable.instance.soundReference == null)             return false;
        var table : SiOPMWavePCMTable = try cast(cast(mmlData, SiMMLData)._getPCMVoice(index).waveData, SiOPMWavePCMTable) catch(e:Dynamic) null;
        if (table == null)             return false;
        return Translator.parsePCMWave(table, dat, SiOPMTable.instance.soundReference);
    }
    
    
    private function __setPCMVoice(index : Int, dat : String, pfx : String) : Bool{
        if (SiOPMTable.instance.soundReference == null)             return false;
        var voice : SiMMLVoice = cast(mmlData, SiMMLData)._getPCMVoice(index);
        if (voice == null)             return false;
        return Translator.parsePCMVoice(voice, dat, pfx, cast((mmlData), SiMMLData).envelopes);
    }
    
    
    
    
    // event handlers
    //----------------------------------------------------------------------------------------------------
    // register process events
    private function _registerProcessEvent() : Void{
        setMMLEventListener(MMLEvent.NOP, _default_onNoOperation);
        setMMLEventListener(MMLEvent.PROCESS, _default_onProcess);
        setMMLEventListener(MMLEvent.REST, _onRest);
        setMMLEventListener(MMLEvent.NOTE, _onNote);
        setMMLEventListener(MMLEvent.SLUR, _onSlur);
        setMMLEventListener(MMLEvent.SLUR_WEAK, _onSlurWeak);
        setMMLEventListener(MMLEvent.PITCHBEND, _onPitchBend);
    }
    
    // register dummy process events
    private function _registerDummyProcessEvent() : Void{
        setMMLEventListener(MMLEvent.NOP, _nop);
        setMMLEventListener(MMLEvent.PROCESS, _dummy_onProcess);
        setMMLEventListener(MMLEvent.REST, _dummy_onProcessEvent);
        setMMLEventListener(MMLEvent.NOTE, _dummy_onProcessEvent);
        setMMLEventListener(MMLEvent.SLUR, _dummy_onProcessEvent);
        setMMLEventListener(MMLEvent.SLUR_WEAK, _dummy_onProcessEvent);
        setMMLEventListener(MMLEvent.PITCHBEND, _dummy_onProcessEvent);
    }
    
    // dummy process event
    private function _dummy_onProcessEvent(e : MMLEvent) : MMLEvent
    {
        return currentExecutor._publishProessingEvent(e);
    }
    
    
    // processing events
    //--------------------------------------------------
    // rest
    private function _onRest(e : MMLEvent) : MMLEvent
    {
        _currentTrack._onRestEvent();
        return currentExecutor._publishProessingEvent(e);
    }
    
    // note
    private function _onNote(e : MMLEvent) : MMLEvent
    {
        _currentTrack._onNoteEvent(e.data, calcSampleCount(e.length));
        return currentExecutor._publishProessingEvent(e);
    }
    
    // SiONDriver.noteOn()
    private function _onDriverNoteOn(e : MMLEvent) : MMLEvent
    {
        _currentTrack.setNote(e.data, calcSampleCount(e.length));
        return currentExecutor._publishProessingEvent(e);
    }
    
    // &
    private function _onSlur(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_SLUR != 0) {
            _currentTrack._changeNoteLength(calcSampleCount(e.length));
        }
        else {
            _currentTrack._onSlur();
        }
        return currentExecutor._publishProessingEvent(e);
    }
    
    // &&
    private function _onSlurWeak(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_SLUR != 0) {
            _currentTrack._changeNoteLength(calcSampleCount(e.length));
        }
        else {
            _currentTrack._onSlurWeak();
        }
        return currentExecutor._publishProessingEvent(e);
    }
    
    // *
    private function _onPitchBend(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_SLUR != 0) {
            _currentTrack._changeNoteLength(calcSampleCount(e.length));
        }
        else {
            if (e.next == null || e.next.id != MMLEvent.NOTE) return e.next;  // check next note
            var term : Int = calcSampleCount(e.length);  // changing time  
            _currentTrack._onPitchBend(e.next.data, term);
        }
        return currentExecutor._publishProessingEvent(e);
    }
    
    
    // driver track events
    //--------------------------------------------------
    // quantize ratio
    private function _onQuantRatio(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_QUANTIZE != 0) return e.next;  // check mask
        _currentTrack.quantRatio = e.data / setting.maxQuantRatio;  // quantize ratio  
        return e.next;
    }
    
    // quantize count
    private function _onQuantCount(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        _p[0] = (_p[0] == INT_MIN_VALUE) ? 0 : Math.floor(_p[0] * setting.resolution / setting.maxQuantCount);
        _p[1] = (_p[1] == INT_MIN_VALUE) ? 0 : Math.floor(_p[1] * setting.resolution / setting.maxQuantCount);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_QUANTIZE != 0) return e.next;  // check mask
        _currentTrack.quantCount = calcSampleCount(_p[0]);  // quantize count  
        _currentTrack.keyOnDelay = calcSampleCount(_p[1]);  // key on delay  
        return e.next;
    }
    
    // @mask
    private function _onEventMask(e : MMLEvent) : MMLEvent
    {
        _currentTrack.eventMask = ((e.data != INT_MIN_VALUE)) ? e.data : 0;
        return e.next;
    }
    
    // k
    private function _onDetune(e : MMLEvent) : MMLEvent
    {
        _currentTrack.pitchShift = ((e.data == INT_MIN_VALUE)) ? 0 : e.data;
        return e.next;
    }
    
    // kt
    private function _onKeyTrans(e : MMLEvent) : MMLEvent
    {
        _currentTrack.noteShift = ((e.data == INT_MIN_VALUE)) ? 0 : e.data;
        return e.next;
    }
    
    // !@kr
    private function _onRelativeDetune(e : MMLEvent) : MMLEvent
    {
        _currentTrack.pitchShift += ((e.data == INT_MIN_VALUE)) ? 0 : e.data;
        return e.next;
    }
    
    
    // envelop events
    //--------------------------------------------------
    // @fps
    private function _onEnvelopFPS(e : MMLEvent) : MMLEvent
    {
        var frame : Int = ((e.data == INT_MIN_VALUE || e.data == 0)) ? 60 : e.data;
        if (frame > 1000)             frame = 1000;
        _currentTrack.setEnvelopFPS(frame);
        return e.next;
    }
    
    // @@
    private function _onToneEnv(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_ENVELOP != 0) return e.next;  // check mask
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 1;
        var idx : Int = ((_p[0] >= 0 && _p[0] < 255)) ? _p[0] : -1;
        _currentTrack.setToneEnvelop(1, _table.getEnvelopTable(idx), _p[1]);
        return e.next;
    }
    
    // na
    private function _onAmplitudeEnv(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_ENVELOP != 0) return e.next;  // check mask
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 1;
        var idx : Int = ((_p[0] >= 0 && _p[0] < 255)) ? _p[0] : -1;
        _currentTrack.setAmplitudeEnvelop(1, _table.getEnvelopTable(idx), _p[1]);
        return e.next;
    }
    
    // !na
    private function _onAmplitudeEnvTSSCP(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_ENVELOP != 0) return e.next;  // check mask
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 1;
        var idx : Int = ((_p[0] >= 0 && _p[0] < 255)) ? _p[0] : -1;
        _currentTrack.setAmplitudeEnvelop(1, _table.getEnvelopTable(idx), _p[1], true);
        return e.next;
    }
    
    // np
    private function _onPitchEnv(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_ENVELOP != 0) return e.next;  // check mask
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 1;
        var idx : Int = ((_p[0] >= 0 && _p[0] < 255)) ? _p[0] : -1;
        _currentTrack.setPitchEnvelop(1, _table.getEnvelopTable(idx), _p[1]);
        return e.next;
    }
    
    // nt
    private function _onNoteEnv(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_ENVELOP != 0) return e.next;  // check mask
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 1;
        var idx : Int = ((_p[0] >= 0 && _p[0] < 255)) ? _p[0] : -1;
        _currentTrack.setNoteEnvelop(1, _table.getEnvelopTable(idx), _p[1]);
        return e.next;
    }
    
    // nf
    private function _onFilterEnv(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_ENVELOP != 0) return e.next;  // check mask
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 1;
        var idx : Int = ((_p[0] >= 0 && _p[0] < 255)) ? _p[0] : -1;
        _currentTrack.setFilterEnvelop(1, _table.getEnvelopTable(idx), _p[1]);
        return e.next;
    }
    
    // _@@
    private function _onToneReleaseEnv(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_ENVELOP != 0) return e.next;  // check mask
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 1;
        var idx : Int = ((_p[0] >= 0 && _p[0] < 255)) ? _p[0] : -1;
        _currentTrack.setToneEnvelop(0, _table.getEnvelopTable(idx), _p[1]);
        return e.next;
    }
    
    // _na
    private function _onAmplitudeReleaseEnv(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_ENVELOP != 0) return e.next;  // check mask
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 1;
        var idx : Int = ((_p[0] >= 0 && _p[0] < 255)) ? _p[0] : -1;
        _currentTrack.setAmplitudeEnvelop(0, _table.getEnvelopTable(idx), _p[1]);
        return e.next;
    }
    
    // _np
    private function _onPitchReleaseEnv(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_ENVELOP != 0) return e.next;  // check mask
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 1;
        var idx : Int = ((_p[0] >= 0 && _p[0] < 255)) ? _p[0] : -1;
        _currentTrack.setPitchEnvelop(0, _table.getEnvelopTable(idx), _p[1]);
        return e.next;
    }
    
    // _nt
    private function _onNoteReleaseEnv(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_ENVELOP != 0) return e.next;  // check mask
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 1;
        var idx : Int = ((_p[0] >= 0 && _p[0] < 255)) ? _p[0] : -1;
        _currentTrack.setNoteEnvelop(0, _table.getEnvelopTable(idx), _p[1]);
        return e.next;
    }
    
    // _nf
    private function _onFilterReleaseEnv(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_ENVELOP != 0) return e.next;  // check mask
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 1;
        var idx : Int = ((_p[0] >= 0 && _p[0] < 255)) ? _p[0] : -1;
        _currentTrack.setFilterEnvelop(0, _table.getEnvelopTable(idx), _p[1]);
        return e.next;
    }
    
    
    // internal table envelop events
    //--------------------------------------------------
    // @f
    private function _onFilter(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 10);
        var cut : Int = ((_p[0] == INT_MIN_VALUE)) ? 128 : _p[0];
        var res : Int = ((_p[1] == INT_MIN_VALUE)) ? 0 : _p[1];
        var ar : Int = ((_p[2] == INT_MIN_VALUE)) ? 0 : _p[2];
        var dr1 : Int = ((_p[3] == INT_MIN_VALUE)) ? 0 : _p[3];
        var dr2 : Int = ((_p[4] == INT_MIN_VALUE)) ? 0 : _p[4];
        var rr : Int = ((_p[5] == INT_MIN_VALUE)) ? 0 : _p[5];
        var dc1 : Int = ((_p[6] == INT_MIN_VALUE)) ? 128 : _p[6];
        var dc2 : Int = ((_p[7] == INT_MIN_VALUE)) ? 64 : _p[7];
        var sc : Int = ((_p[8] == INT_MIN_VALUE)) ? 32 : _p[8];
        var rc : Int = ((_p[9] == INT_MIN_VALUE)) ? 128 : _p[9];
        _currentTrack.channel.setSVFilter(cut, res, ar, dr1, dr2, rr, dc1, dc2, sc, rc);
        return e.next;
    }
    
    // %f
    private function _onFilterMode(e : MMLEvent) : MMLEvent
    {
        _currentTrack.channel.filterType = e.data;
        return e.next;
    }
    
    // @lfo[cycle_frames],[ws]
    private function _onLFO(e : MMLEvent) : MMLEvent
    {
        // get parameters
        e = e.getParameters(_p, 2);
        if (_p[1] > 7 && _p[1] < 255) {  // custom table  
            var env : SiMMLEnvelopTable = _table.getEnvelopTable(_p[1]);
            if (env != null)                 _currentTrack.channel.initializeLFO(-1, env.toVector(256, 0, 255))
            else _currentTrack.channel.initializeLFO(SiOPMTable.LFO_WAVE_TRIANGLE);
        }
        else {
            _currentTrack.channel.initializeLFO(((_p[1] == INT_MIN_VALUE)) ? SiOPMTable.LFO_WAVE_TRIANGLE : _p[1]);
        }
        _currentTrack.channel.setLFOCycleTime(((_p[0] == INT_MIN_VALUE)) ? 333 : _p[0] * 1000 / 60);
        return e.next;
    }
    
    // mp [depth],[end_depth],[delay],[term]
    private function _onPitchModulation(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 4);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_MODULATE != 0) return e.next;  // check mask
        if (_p[0] == INT_MIN_VALUE)             _p[0] = 0;
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 0;
        if (_p[2] == INT_MIN_VALUE)             _p[2] = 0;
        if (_p[3] == INT_MIN_VALUE)             _p[3] = 0;
        _currentTrack.setModulationEnvelop(true, _p[0], _p[1], _p[2], _p[3]);
        return e.next;
    }
    
    // ma [depth],[end_depth],[delay],[term]
    private function _onAmplitudeModulation(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 4);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_MODULATE != 0) return e.next;  // check mask
        if (_p[0] == INT_MIN_VALUE)             _p[0] = 0;
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 0;
        if (_p[2] == INT_MIN_VALUE)             _p[2] = 0;
        if (_p[3] == INT_MIN_VALUE)             _p[3] = 0;
        _currentTrack.setModulationEnvelop(false, _p[0], _p[1], _p[2], _p[3]);
        return e.next;
    }
    
    // po [term]
    private function _onPortament(e : MMLEvent) : MMLEvent
    {
        if (e.data == INT_MIN_VALUE)             e.data = 0;
        _currentTrack.setPortament(e.data);
        return e.next;
    }
    
    
    // i/o events
    //--------------------------------------------------
    // v
    private function _onVolume(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_VOLUME != 0) return e.next;  // check mask
        _currentTrack._mmlVCommand(e.data);  // velocity (data<<3 = 16->128)  
        return e.next;
    }
    
    // (, )
    private function _onVolumeShift(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_VOLUME != 0) return e.next;  // check mask
        _currentTrack._mmlVShift(e.data);  // velocity (data<<3 = 16->128)  
        return e.next;
    }
    
    // %v
    private function _onVolumeSetting(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, SiOPMModule.STREAM_SEND_SIZE);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_VOLUME != 0) return e.next;  // check mask
        _currentTrack._vcommandShift = ((_p[1] == INT_MIN_VALUE)) ? 4 : _p[1];
        _currentTrack.velocityMode = ((_p[0] == INT_MIN_VALUE)) ? 0 : _p[0];
        return e.next;
    }
    
    // x
    private function _onExpression(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_VOLUME != 0) return e.next;  // check mask
        var x : Int = ((e.data == INT_MIN_VALUE)) ? 128 : e.data;  // default value = 128  
        _currentTrack.expression = x;  // expression  
        return e.next;
    }
    
    // %x
    private function _onExpressionSetting(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_VOLUME != 0) return e.next;  // check mask
        _currentTrack.expressionMode = ((e.data == INT_MIN_VALUE)) ? 0 : e.data;
        return e.next;
    }
    
    // @v
    private function _onMasterVolume(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, SiOPMModule.STREAM_SEND_SIZE);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_VOLUME != 0) return e.next;  // check mask
        _currentTrack.channel.setAllStreamSendLevels(_p);  // master volume  
        return e.next;
    }
    
    // p
    private function _onPan(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_PAN != 0) return e.next;  // check mask
        _currentTrack.channel.pan = ((e.data == INT_MIN_VALUE)) ? 0 : (e.data << 4) - 64;  // pan  
        return e.next;
    }
    
    // @p
    private function _onFinePan(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_PAN != 0) return e.next;  // check mask
        _currentTrack.channel.pan = ((e.data == INT_MIN_VALUE)) ? 0 : (e.data);  // pan  
        return e.next;
    }
    
    // @i
    private function _onInput(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_p[0] == INT_MIN_VALUE)             _p[0] = 5;
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 0;
        _currentTrack.channel.setInput(_p[0], _p[1]);
        return e.next;
    }
    
    // @o
    private function _onOutput(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_p[0] == INT_MIN_VALUE)             _p[0] = 2;
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 0;
        _currentTrack.channel.setOutput(_p[0], _p[1]);
        return e.next;
    }
    
    // @r
    private function _onRingModulation(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_p[0] == INT_MIN_VALUE)             _p[0] = 4;
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 0;
        _currentTrack.channel.setRingModulation(_p[0], _p[1]);
        return e.next;
    }
    
    
    // sound channel events
    //--------------------------------------------------
    // %
    private function _onModuleType(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_p[0] < 0 || _p[0] >= SiMMLTable.MT_MAX)             _p[0] = SiMMLTable.MT_ALL;
        _currentTrack.setChannelModuleType(_p[0], _p[1]);
        return e.next;
    }
    
    
    // %t
    private function _setEventTrigger(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 3);
        var id : Int = ((_p[0] != INT_MIN_VALUE)) ? _p[0] : 0;
        var typeOn : Int = ((_p[1] != INT_MIN_VALUE)) ? _p[1] : 1;
        var typeOff : Int = ((_p[2] != INT_MIN_VALUE)) ? _p[2] : 1;
        _currentTrack.setEventTrigger(id, typeOn, typeOff);
        return e.next;
    }
    
    
    // %e
    private function _dispatchEvent(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        var id : Int = ((_p[0] != INT_MIN_VALUE)) ? _p[0] : 0;
        var typeOn : Int = ((_p[1] != INT_MIN_VALUE)) ? _p[1] : 1;
        _currentTrack.dispatchNoteOnEvent(id, typeOn);
        return e.next;
    }
    
    
    // @clock
    private function _onClock(e : MMLEvent) : MMLEvent
    {
        _currentTrack.channel.setFrequencyRatio(((e.data == INT_MIN_VALUE)) ? 100 : (e.data));
        return e.next;
    }
    
    
    // @al
    private function _onAlgorism(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        var cnt : Int = ((_p[0] != INT_MIN_VALUE)) ? _p[0] : 0;
        var alg : Int = ((_p[1] != INT_MIN_VALUE)) ? _p[1] : _table.alg_init[cnt];
        _currentTrack.channel.setAlgorism(cnt, alg);
        return e.next;
    }
    
    // @
    private function _onOpeParameter(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, PARAM_MAX);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        var seq : MMLSequence = _currentTrack._setChannelParameters(_p);
        if (seq != null) {
            seq.connectBefore(e.next);
            return seq.headEvent.next;
        }
        return e.next;
    }
    
    // @fb
    private function _onFeedback(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        var fb : Int = ((_p[0] != INT_MIN_VALUE)) ? _p[0] : 0;
        var fbc : Int = ((_p[1] != INT_MIN_VALUE)) ? _p[1] : 0;
        _currentTrack.channel.setFeedBack(fb, fbc);
        return e.next;
    }
    
    // i
    private function _onSlotIndex(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        _currentTrack.channel.activeOperatorIndex = ((e.data == INT_MIN_VALUE)) ? 4 : e.data;
        return e.next;
    }
    
    
    // @rr
    private function _onOpeReleaseRate(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        if (_p[0] != INT_MIN_VALUE)             _currentTrack.channel.rr = _p[0];
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 0;
        _currentTrack.setReleaseSweep(_p[1]);
        return e.next;
    }
    
    // @tl
    private function _onOpeTotalLevel(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        _currentTrack.channel.tl = ((e.data == INT_MIN_VALUE)) ? 0 : e.data;
        return e.next;
    }
    
    // @ml
    private function _onOpeMultiple(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        if (_p[0] == INT_MIN_VALUE)             _p[0] = 0;
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 0;
        _currentTrack.channel.fmul = (_p[0] << 7) + _p[1];
        return e.next;
    }
    
    // @dt
    private function _onOpeDetune(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        _currentTrack.channel.detune = ((e.data == INT_MIN_VALUE)) ? 0 : e.data;
        return e.next;
    }
    
    // @ph
    private function _onOpePhase(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        var phase : Int = ((e.data == INT_MIN_VALUE)) ? 0 : e.data;
        _currentTrack.channel.phase = phase;  // -1 = 255  
        return e.next;
    }
    
    // @fx
    private function _onOpeFixedNote(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        if (_p[0] == INT_MIN_VALUE)             _p[0] = 0;
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 0;
        _currentTrack.channel.fixedPitch = (_p[0] << 6) + _p[1];
        return e.next;
    }
    
    // @se
    private function _onOpeSSGEnvelop(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        _currentTrack.channel.ssgec = ((e.data == INT_MIN_VALUE)) ? 0 : e.data;
        return e.next;
    }
    
    // @er
    private function _onOpeEnvelopReset(e : MMLEvent) : MMLEvent
    {
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        _currentTrack.channel.erst = (e.data == 1);
        return e.next;
    }
    
    // s
    private function _onSustain(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        if (_currentTrack.eventMask & SiMMLTrack.MASK_OPERATOR != 0) return e.next;  // check mask
        if (_p[0] != INT_MIN_VALUE)             _currentTrack.channel.setAllReleaseRate(_p[0]);
        if (_p[1] == INT_MIN_VALUE)             _p[1] = 0;
        _currentTrack.setReleaseSweep(_p[1]);
        return e.next;
    }
    
    
    // register event
    private function _onRegisterUpdate(e : MMLEvent) : MMLEvent
    {
        e = e.getParameters(_p, 2);
        _currentTrack._callbackUpdateRegister(_p[0], _p[1]);
        return e.next;
    }
    
    
    
    
    
    // errors
    //--------------------------------------------------
    private function _errorSyntax(str : String) : Error
    {
        return new Error("SiMMLSequencer error : Syntax error. " + str);
    }
    
    
    private function _errorOutOfRange(cmd : String, n : Int) : Error
    {
        return new Error("SiMMLSequencer error : Out of range. '" + cmd + "' = " + Std.string(n));
    }
    
    
    private function _errorToneParameterNotValid(cmd : String, chParam : Int, opParam : Int) : Error
    {
        return new Error("SiMMLSequencer error : Parameter count is not valid in '" + cmd + "'. " + Std.string(chParam) + " parameters for channel and " + Std.string(opParam) + " parameters for each operator.");
    }
    
    
    private function _errorParameterNotValid(cmd : String, param : String) : Error
    {
        return new Error("SiMMLSequencer error : Parameter not valid. '" + param + "' in " + cmd);
    }
    
    
    private function _errorInternalTable() : Error
    {
        return new Error("SiMMLSequencer error : Internal table is available only for envelop commands.");
    }
    
    
    private function _errorCircularReference(mcr : String) : Error
    {
        return new Error("SiMMLSequencer error : Circular reference in dynamic macro. " + mcr);
    }
    
    
    private function _errorInitSequence(mml : String) : Error
    {
        return new Error("SiMMLSequencer error : Initializing sequence cannot include note, rest, '%' nor '@'. " + mml);
    }
    
    
    private function _errorSystemCommand(str : String) : Error
    {
        return new Error("SiMMLSequencer error : System command error. " + str);
    }
    
    
    private function _errorUnknown(str : String) : Error
    {
        return new Error("SiMMLSequencer error : Unknown. " + str);
    }
}


