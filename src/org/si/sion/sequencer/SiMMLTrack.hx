//----------------------------------------------------------------------------------------------------
// Track for SiMMLSequencer.
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.sion.sequencer;

import org.si.utils.SLLint;
import org.si.sion.module.channels.SiOPMChannelBase;
import org.si.sion.module.SiOPMTable;
import org.si.sion.sequencer.base.MMLData;
import org.si.sion.sequencer.base.MMLEvent;
import org.si.sion.sequencer.base.MMLSequence;
import org.si.sion.sequencer.base.MMLExecutor;
import org.si.sion.sequencer.base.BeatPerMinutes;

import org.si.sion.sequencer.simulator.SiMMLSimulatorBase;



/** Track is a musical sequence player for one voice.
 */
class SiMMLTrack
{
    public var trackNumber(get, never) : Int;
    public var trackID(get, never) : Int;
    public var trackTypeID(get, never) : Int;
    public var eventTriggerID(get, never) : Int;
    public var eventTriggerTypeOn(get, never) : Int;
    public var eventTriggerTypeOff(get, never) : Int;
    public var note(get, never) : Int;
    public var trackStartDelay(get, never) : Int;
    public var trackStopDelay(get, never) : Int;
    public var isActive(get, never) : Bool;
    public var isDisposable(get, never) : Bool;
    public var isPlaySequence(get, never) : Bool;
    public var isFinished(get, never) : Bool;
    public var velocity(get, set) : Int;
    public var expression(get, set) : Int;
    public var masterVolume(get, set) : Int;
    public var effectSend1(get, set) : Int;
    public var effectSend2(get, set) : Int;
    public var effectSend3(get, set) : Int;
    public var effectSend4(get, set) : Int;
    public var mute(get, set) : Bool;
    public var pan(get, set) : Int;
    public var pitchBend(get, set) : Int;
    public var onUpdateRegister(get, set) : Int->Int->Void;
    public var velocityMode(get, set) : Int;
    public var expressionMode(get, set) : Int;
    public var channelNumber(get, never) : Int;
    public var programNumber(get, never) : Int;
    public var outputLevel(get, never) : Float;
    public var mmlData(get, never) : SiMMLData;
    public var _bpmSetting(get, never) : BeatPerMinutes;
    public var priority(get, never) : Int;

    // constants
    //--------------------------------------------------
    /** sweep step finess */
    private static inline var SWEEP_FINESS : Int = 128;
    /** Fixed decimal bits. */
    private static inline var FIXED_BITS : Int = 16;
    /** Maximum value of _sweep */
    private static var SWEEP_MAX : Int = 8192 << FIXED_BITS;

    public static inline var INT_MIN_VALUE = -2147483648;

    // track id type
    /** @private [internal use] track id filter */
    public static inline var TRACK_ID_FILTER : Int = 0xffff;
    /** @private [internal use] track type filter */
    private static inline var TRACK_TYPE_FILTER : Int = 0xff0000;
    
    /** Track Type ID for main MML tracks */
    public static inline var MML_TRACK : Int = 0x10000;
    /** Track Type ID for MIDI tracks */
    public static inline var MIDI_TRACK : Int = 0x20000;
    /** Track Type ID for tracks created by SiONDriver.noteOn() or SiONDriver.playSound() */
    public static inline var DRIVER_NOTE : Int = 0x30000;
    /** Track Type ID for tracks created by SiONDriver.sequenceOn() */
    public static inline var DRIVER_SEQUENCE : Int = 0x40000;
    /** Track Type ID for SiONDriver's background sound tracks */
    public static inline var DRIVER_BACKGROUND : Int = 0x50000;
    /** Track Type ID for user controlled tracks */
    public static inline var USER_CONTROLLED : Int = 0x60000;
    
    // mask bits for eventMask and @mask command
    /** no event mask */
    public static inline var NO_MASK : Int = 0;
    /** mask all volume commands (v,x,&#64;v,"(",")") */
    public static inline var MASK_VOLUME : Int = 1;
    /** mask all panning commands (p,&#64;p) */
    public static inline var MASK_PAN : Int = 2;
    /** mask all quantize commands (q,&#64;q) */
    public static inline var MASK_QUANTIZE : Int = 4;
    /** mask all operator setting commands (s,&#64;al,&#64;fb,i,&#64;,&#64;rr,&#64;tl,&#64;ml,&#64;st,&#64;ph,&#64;fx,&#64;se,&#64;er) */
    public static inline var MASK_OPERATOR : Int = 8;
    /** mask all table envelop commands (&#64;&#64;,na,np,nt,nf,_&#64;&#64;,_na,_np,_nt,_nf) */
    public static inline var MASK_ENVELOP : Int = 16;
    /** mask all modulation commands (ma,mp) */
    public static inline var MASK_MODULATE : Int = 32;
    /** mask all slur and pitch-bending commands (&amp;,&amp;&amp;,*) */
    public static inline var MASK_SLUR : Int = 64;
    
    // _processMode
    private static inline var NORMAL : Int = 0;
    private static inline var ENVELOP : Int = 2;
    
    
    
    
    // variables
    //--------------------------------------------------
    /** Sound module's channel controlled by this track. */
    public var channel : SiOPMChannelBase;
    
    /** MML sequence executor */
    public var executor : MMLExecutor;
    
    /** note shift, set by kt command.  */
    public var noteShift : Int = 0;
    /** detune, set by k command.  */
    public var pitchShift : Int = 0;
    /** key on delay, set by 2nd argument of &#64;q command.  */
    public var keyOnDelay : Int = 0;
    /** quantize ratio, set by q command, the value is between 0-1.  */
    public var quantRatio : Float = 0;
    /** quantize count, set by &#64;q command. */
    public var quantCount : Int = 0;
    /** Event mask, set by &#64;mask command. */
    public var eventMask : Int = 0;
    
    // call back function before noteOn/noteOff
    private var _callbackBeforeNoteOn : SiMMLTrack->Bool = null;
    private var _callbackBeforeNoteOff : SiMMLTrack->Bool = null;
    @:allow(org.si.sion.sequencer)
    private var _callbackUpdateRegister : Int->Int->Void = null;
    
    // event trigger
    private var _eventTriggerOn : SiMMLTrack->Bool = null;
    private var _eventTriggerOff : SiMMLTrack->Bool = null;
    private var _eventTriggerID : Int;
    private var _eventTriggerTypeOn : Int;
    private var _eventTriggerTypeOff : Int;
    
    // track ID number
    public var _internalTrackID : Int;
    public var _trackNumber : Int;
    
    // internal use
    private var _mmlData : SiMMLData;  // mml data. To get bpm from sequenceOn()s track, or only for reference in other cases.  
    private var _table : SiMMLTable;  // table  
    private var _keyOnCounter : Int;  // key on counter  
    private var _keyOnLength : Int;  // key on length  
    private var _flagNoKeyOn : Bool;  // key on flag  
    private var _processMode : Int;  // processing mode  
    private var _trackStartDelay : Int;  // track delay to start  
    private var _trackStopDelay : Int;  // track delay to stop  
    private var _stopWithReset : Bool;  // stop with reset  
    private var _isDisposable : Bool;  // flag disposable track  
    private var _priority : Int;  // track priority  
    
    // settings
    private var _channelModuleSetting : SiMMLChannelSetting;  // selected module's setting  
    private var _simulator : SiMMLSimulatorBase;  // simulator  
    
    private var _velocityMode : Int;  // velocity mode  
    private var _expressionMode : Int;  // expression mode  
    private var _velocity : Int;  // velocity[0-256-512]  
    private var _expression : Int;  // expression[0-128]  
    private var _pitchIndex : Int;  // current pitch index  
    private var _pitchBend : Int;  // pitch bend  
    private var _voiceIndex : Int;  // tone number  
    private var _note : Int;  // note number  
    private var _defaultFPS : Int;  // default fps  
    /** @private [internal] channel number. */
    public var _channelNumber : Int;
    /** @private [internal] vcommand shift. */
    public var _vcommandShift : Int;  // vcommand shift
    
    // setting
    private var _set_processMode : Array<Int>;
    
    // envelop settings
    private var _set_env_exp : Array<SLLint>;
    private var _set_env_voice : Array<SLLint>;
    private var _set_env_note : Array<SLLint>;
    private var _set_env_pitch : Array<SLLint>;
    private var _set_env_filter : Array<SLLint>;
    private var _set_exp_offset : Array<Bool>;
    private var _pns_or : Array<Bool>;
    
    private var _set_cnt_exp : Array<Int>;
    private var _set_cnt_voice : Array<Int>;
    private var _set_cnt_note : Array<Int>;
    private var _set_cnt_pitch : Array<Int>;
    private var _set_cnt_filter : Array<Int>;
    
    private var _table_env_ma : Array<SLLint>;
    private var _table_env_mp : Array<SLLint>;
    private var _set_sweep_step : Array<Int>;
    private var _set_sweep_end : Array<Int>;
    private var _env_internval : Int;
    
    // executing envelope
    private var _env_exp : SLLint;
    private var _env_voice : SLLint;
    private var _env_note : SLLint;
    private var _env_pitch : SLLint;
    private var _env_filter : SLLint;
    
    private var _cnt_exp : Int;private var _max_cnt_exp : Int;
    private var _cnt_voice : Int;private var _max_cnt_voice : Int;
    private var _cnt_note : Int;private var _max_cnt_note : Int;
    private var _cnt_pitch : Int;private var _max_cnt_pitch : Int;
    private var _cnt_filter : Int;private var _max_cnt_filter : Int;
    
    private var _env_mp : SLLint;
    private var _env_ma : SLLint;
    private var _sweep_step : Int;
    private var _sweep_end : Int;
    private var _sweep_pitch : Int;
    private var _env_exp_offset : Int;
    private var _env_pitch_active : Bool;
    
    private var _residue : Int;  // residue of previous envelop process  
    
    // zero table
    private static var _env_zero_table : SLLint = SLLint.allocRing(1);
    
    
    
    
    // properties
    //--------------------------------------------------
    /** track number, this value is unique and set by system, the lower numbered track processes sound first. */
    private function get_trackNumber() : Int{
        return _trackNumber;
    }
    /** track ID, this value is specifyed by user. */
    private function get_trackID() : Int{
        return _internalTrackID & TRACK_ID_FILTER;
    }
    /** track type, this value shows what this track starts by. */
    private function get_trackTypeID() : Int{
        return _internalTrackID & TRACK_TYPE_FILTER;
    }
    
    /** event trigger ID. eventTriggerID=-1 means tigger not set. */
    private function get_eventTriggerID() : Int{
        return _eventTriggerID;
    }
    /** Note on event trigger type. eventTriggerTypeOn=0 means tigger not set. */
    private function get_eventTriggerTypeOn() : Int{
        return _eventTriggerTypeOn;
    }
    /** Note off event trigger type. eventTriggerTypeOff=0 means tigger not set. */
    private function get_eventTriggerTypeOff() : Int{
        return _eventTriggerTypeOff;
    }
    
    /** Note number */
    private function get_note() : Int{
        return _note;
    }
    
    /** Start delay in sample count. Ussualy this returns 0 except after SiONDriver.noteOn. */
    private function get_trackStartDelay() : Int{
        return _trackStartDelay;
    }
    /** Stop delay in sample count. Ussualy this returns 0 except after SiONDriver.noteOff. */
    private function get_trackStopDelay() : Int{
        return _trackStopDelay;
    }
    
    /** Is activate ? This function always returns true from not-disposable track. (isActive = !isDisposable || !isFinished) */
    private function get_isActive() : Bool{
        return !_isDisposable || executor.pointer != null || !channel.isIdling;
    }
    /** Is this track disposable ? Disposable track will free automatically when finished rendering. */
    private function get_isDisposable() : Bool{
        return _isDisposable;
    }
    /** Is playing sequence ? */
    private function get_isPlaySequence() : Bool{
        return ((_internalTrackID & TRACK_TYPE_FILTER) != DRIVER_NOTE && executor.pointer != null);
    }
    /** Is finish to rendering ? */
    private function get_isFinished() : Bool{
        return (executor.pointer == null && channel.isIdling);
    }
    
    /** velocity(0-256). linked to operator's total level. */
    private function get_velocity() : Int{
        return _velocity;
    }
    private function set_velocity(v : Int) : Int{
        _velocity = ((v < 0)) ? 0 : ((v > 512)) ? 512 : v;
        channel.offsetVolume(_expression, _velocity);
        return v;
    }
    
    /** expression(0-128). linked to operator's total level. */
    private function get_expression() : Int{
        return _expression;
    }
    private function set_expression(x : Int) : Int{
        _expression = ((x < 0)) ? 0 : ((x > 128)) ? 128 : x;
        channel.offsetVolume(_expression, _velocity);
        return x;
    }
    
    /** master volume(0-128). simple wrapper of channel.masterVolume. */
    private function get_masterVolume() : Int{
        return channel.masterVolume;
    }
    private function set_masterVolume(v : Int) : Int{
        channel.masterVolume = v;
        return v;
    }
    
    /** effect send level for slot1 (0-128). simple wrapper of channel.setStreamSend. */
    private function get_effectSend1() : Int{
        return Math.round(channel.getStreamSend(1));
    }
    private function set_effectSend1(s : Int) : Int{
        channel.setStreamSend(1, ((s < 0)) ? 0 : ((s > 128)) ? 1 : s * 0.0078125);
        return s;
    }
    
    /** effect send level for slot2 (0-128). simple wrapper of channel.setStreamSend. */
    private function get_effectSend2() : Int{
        return Math.round(channel.getStreamSend(2));
    }
    private function set_effectSend2(s : Int) : Int{
        channel.setStreamSend(2, ((s < 0)) ? 0 : ((s > 128)) ? 1 : s * 0.0078125);
        return s;
    }
    
    /** effect send level for slot3 (0-128). simple wrapper of channel.setStreamSend. */
    private function get_effectSend3() : Int{
        return Math.round(channel.getStreamSend(3));
    }
    private function set_effectSend3(s : Int) : Int{
        channel.setStreamSend(3, ((s < 0)) ? 0 : ((s > 128)) ? 1 : s * 0.0078125);
        return s;
    }
    
    /** effect send level for slot4 (0-128). simple wrapper of channel.setStreamSend. */
    private function get_effectSend4() : Int{
        return Math.round(channel.getStreamSend(4));
    }
    private function set_effectSend4(s : Int) : Int{
        channel.setStreamSend(4, ((s < 0)) ? 0 : ((s > 128)) ? 1 : s * 0.0078125);
        return s;
    }
    
    /** mute */
    private function get_mute() : Bool{
        return channel.mute;
    }
    private function set_mute(b : Bool) : Bool{
        channel.mute = b;
        return b;
    }
    
    /** pannning (-64 - +64)*/
    private function get_pan() : Int{
        return channel.pan;
    }
    private function set_pan(p : Int) : Int{channel.pan = p;
        return p;
    }
    
    /** pitch bend */
    private function get_pitchBend() : Int{
        return _pitchBend;
    }
    private function set_pitchBend(p : Int) : Int{
        _pitchBend = p;
        channel.pitch = _pitchIndex + _pitchBend;
        return p;
    }
    
    /** callback function when update register event appears. */
    private function get_onUpdateRegister() : Int->Int->Void{
        return _callbackUpdateRegister;
    }
    private function set_onUpdateRegister(func : Int->Int->Void) : Int->Int->Void{
        _callbackUpdateRegister = (func != null) ? func : _defaultUpdateRegister;
        return func;
    }
    
    /** velocity table mode */
    private function get_velocityMode() : Int{
        return _velocityMode;
    }
    private function set_velocityMode(mode : Int) : Int{
        var tlTables : Array<Array<Int>> = SiOPMTable.instance.eg_tlTables;
        _velocityMode = ((mode >= 0 && mode < SiOPMTable.VM_MAX)) ? mode : SiOPMTable.VM_LINEAR;
        channel.setVolumeTables(tlTables[_velocityMode], tlTables[_expressionMode]);
        return mode;
    }
    
    /** expression table mode */
    private function get_expressionMode() : Int{
        return _expressionMode;
    }
    private function set_expressionMode(mode : Int) : Int{
        var tlTables : Array<Array<Int>> = SiOPMTable.instance.eg_tlTables;
        _expressionMode = ((mode >= 0 && mode < SiOPMTable.VM_MAX)) ? mode : SiOPMTable.VM_LINEAR;
        channel.setVolumeTables(tlTables[_velocityMode], tlTables[_expressionMode]);
        return mode;
    }
    
    
    /** Channel number, set by 2nd argument of % command. Usually same as programNumber (except for APU). @see programNumber */
    private function get_channelNumber() : Int{
        return _channelNumber;
    }
    /** Program number, set by 2nd argument of % command and 1st arg. of &#64; command. Usually same as channelNumber (except for APU). @see channelNumber */
    private function get_programNumber() : Int{
        return _voiceIndex;
    }
    
    /** output level = &#64;v * v * x. */
    private function get_outputLevel() : Float{
        var vol : Int = channel.masterVolume;
        if (vol == 0)             return _velocity * _expression * 0.0000152587890625 ;
        // 0.5/(128*256);
        return vol * _velocity * _expression * 2.384185791015625e-7;
    }
    
    /** mml data to play. this value only is available in the track playing mml sequence */
    private function get_mmlData() : SiMMLData{
        return _mmlData;
    }
    
    /** @private [internal] bpm setting. refer from SiMMLSequencer */
    @:allow(org.si.sion.sequencer)
    private function get__bpmSetting() : BeatPerMinutes{
        return (((_internalTrackID & TRACK_TYPE_FILTER) != MML_TRACK && _mmlData != null)) ? _mmlData._initialBPM : null;
    }
    
    /** @private [internal] priority number to overwrite when tracks are overflow. */
    private function get_priority() : Int{
        // not-disposable track or sequence playing track always returns highest priority
        if (!_isDisposable || isPlaySequence)             return 0;
        return _priority;
    }
    
    
    
    
    // constructor
    //--------------------------------------------------
    public function new()
    {
        _table = SiMMLTable.instance;
        executor = new MMLExecutor();
        
        _mmlData = null;
        _set_processMode = new Array<Int>();
        
        _set_env_exp = new Array<SLLint>();
        _set_env_voice = new Array<SLLint>();
        _set_env_note = new Array<SLLint>();
        _set_env_pitch = new Array<SLLint>();
        _set_env_filter = new Array<SLLint>();
        _pns_or = new Array<Bool>();
        _set_exp_offset = new Array<Bool>();
        _set_cnt_exp = new Array<Int>();
        _set_cnt_voice = new Array<Int>();
        _set_cnt_note = new Array<Int>();
        _set_cnt_pitch = new Array<Int>();
        _set_cnt_filter = new Array<Int>();
        _set_sweep_step = new Array<Int>();
        _set_sweep_end = new Array<Int>();
        _table_env_ma = new Array<SLLint>();
        _table_env_mp = new Array<SLLint>();

        _callbackUpdateRegister = _defaultUpdateRegister;
    }
    
    
    
    
    // interfaces for intaractive operations
    //--------------------------------------------------
    /** Set track callback function. The callback functions are called at the timing of streaming before SiOPMEvent.STREAM event.
     *  @param noteOn Callback function before note on. This function refers this track instance and new pitch (0-8191) as an arguments. When the function returns false, noteOn will be canceled.<br/>
     *  function callbackNoteOn(track:SiMMLTrack) : Boolean { return true; }
     *  @param noteOff Callback function before note off. This function refers this track instance as an argument. When the function returns false, noteOff will be canceled.<br/>
     *  function callbackNoteOff(track:SiMMLTrack) : Boolean { return true; }
     */
    public function setTrackCallback(noteOn : SiMMLTrack->Bool = null, noteOff : SiMMLTrack->Bool = null) : SiMMLTrack
    {
        _callbackBeforeNoteOn = noteOn;
        _callbackBeforeNoteOff = noteOff;
        return this;
    }
    
    
    /** key on. SiONDriver.noteOn() calls this internally.
     *  @param note Note number
     *  @param tickLength note length in tick count.
     *  @param sampleDelay note delay in sample count.
     */
    public function keyOn(note : Int, tickLength : Int = 0, sampleDelay : Int = 0) : SiMMLTrack
    {
        _trackStartDelay = sampleDelay;
        executor.singleNote(note, tickLength);
        return this;
    }
    
    
    /** Force key off. SiONDriver.noteOff() calls this internally.
     *  @param sampleDelay Delay time (in sample count).
     *  @param stopWithReset Stop with channel resetting.
     */
    public function keyOff(sampleDelay : Int = 0, stopWithReset : Bool = false) : SiMMLTrack
    {
        _stopWithReset = stopWithReset;
        if (sampleDelay != 0) {
            _trackStopDelay = sampleDelay;
        }
        else {
            _keyOff();
            _note = -1;
            if (_stopWithReset)                 channel.reset();
        }
        return this;
    }
    
    
    /** dispatch EventTrigger 
     *  @param noteOn noteOn event or noteOff event
     *  @return returns false when the event is prevented
     */
    public function dispatchEventTrigger(noteOn : Bool) : Bool
    {
        if (noteOn) {
            if (_callbackBeforeNoteOn != null)                 return _callbackBeforeNoteOn(this);
        }
        else {
            if (_callbackBeforeNoteOff != null)                 return _callbackBeforeNoteOff(this);
        }
        return false;
    }
    
    
    /** Play sequence.
     *  @param seq Sequence to play.
     *  @param sampleLength sequence playing time.
     *  @param sampleDelay Delaying time (in sample count).
     */
    public function sequenceOn(seq : MMLSequence, sampleLength : Int = 0, sampleDelay : Int = 0) : SiMMLTrack
    {
        trace('SiMMLTrack.sequenceOn($seq)');
        _trackStartDelay = sampleDelay;
        _trackStopDelay = sampleLength;
        _mmlData = (seq != null) ? (try cast(seq._owner, SiMMLData) catch(e:Dynamic) null) : null;
        trace('  start: $_trackStartDelay stop: $_trackStopDelay MML: $_mmlData');
        executor.initialize(seq);
        return this;
    }
    
    
    /** Force stop sequence.
     *  @param sampleDelay Delay time (in sample count).
     *  @param stopWithReset Stop with channel resetting.
     */
    public function sequenceOff(sampleDelay : Int = 0, stopWithReset : Bool = false) : SiMMLTrack
    {
        _stopWithReset = stopWithReset;
        if (sampleDelay != 0) {
            _trackStopDelay = sampleDelay;
        }
        else {
            executor.clear();
            if (_stopWithReset)                 channel.reset();
        }
        return this;
    }
    
    
    /** Limit key on length. 
     *  @param stopDelay delay to key-off.
     */
    public function limitLength(stopDelay : Int) : Void
    {
        var length : Int = stopDelay - _trackStartDelay;
        if (length < _keyOnLength) {
            _keyOnLength = length;
            _keyOnCounter = _keyOnLength;
        }
    }
    
    
    /** Set this track disposable. */
    public function setDisposable() : Void
    {
        _isDisposable = true;
    }
    
    
    
    
    // interfaces for mml command
    //--------------------------------------------------
    /** Set note immediately. 
     *  The calling path : SiONDriver.noteOn() -> SiMMLTrack.keyOn() -> executor.singleNote() ->(waiting for MMLEvent.DRIVER_NOTE)
     *  -> SiMMLSequencer._onDriverNoteOn() -> SiMMLTrack.setNote() -> SiMMLTrack._mmlKeyOn().
     *  @param note note number.
     *  @param sampleLength length in sample count. 0 sets no key off (=weak slur).
     *  @param slur set as slur.
     */
    public function setNote(note : Int, sampleLength : Int, slur : Bool = false) : Void
    {
        // play with key off when quantRatio == 0 or sampleLength != 0
        if ((quantRatio == 0 || sampleLength > 0) && !slur) {
            _keyOnLength = Math.floor(sampleLength * quantRatio) - quantCount - keyOnDelay;
            if (_keyOnLength < 1)                 _keyOnLength = 1;
        }
        else {
            // no key off
            _keyOnLength = 0;
        }
        _mmlKeyOn(note);
        _flagNoKeyOn = slur;
    }
    
    
    /** Set pitch bending.
     *  @param noteFrom Note number bending from.
     *  @param tickLength length of pitch bending.
     */
    public function setPitchBend(noteFrom : Int, tickLength : Int) : Void
    {
        executor.bendingFrom(noteFrom, tickLength);
    }
    
    
    /** Channel module type (%) and select tone (1st argument of '_&#64;').
     *  @param type Channel module type
     *  @param channelNum Channel number. For %2-11, this value is same as 1st argument of '_&#64;'. channel number of -1 ignores all voice settings by selectVoice.
     *  @param toneNum Tone number. Ussualy, this argument is used only in %0;PSG and %1;APU.
     */
    public function setChannelModuleType(type : Int, channelNum : Int = INT_MIN_VALUE, toneNum : Int = INT_MIN_VALUE) : Void
    {
        // change module type
        _channelModuleSetting = _table.channelModuleSetting[type];
        //_simulator = _table.simulators[type];
        
        // reset operator pgType, set SiMMLTrack._channelNumber inside
        _voiceIndex = _channelModuleSetting.initializeTone(this, channelNum, channel.bufferIndex);
        //_voiceIndex = _simulator.initializeTone(this, channelNum, channel.bufferIndex);
        
        
        // select tone
        if (toneNum >= 0) {
            _voiceIndex = toneNum;
            _channelModuleSetting.selectTone(this, toneNum);
        }
    }
    
    
    /** portament (po).
     *  @param frame portament changing time in frame count.
     */
    public function setPortament(frame : Int) : Void
    {
        _set_sweep_step[1] = frame;
        if (frame != 0) {
            _pns_or[1] = true;
            _envelopOn(1);
        }
        else {
            _envelopOff(1);
        }
    }
    
    
    /** set event trigger (%t) 
     *  @param id Event trigger ID of this track. This value can be refered from SiONTrackEvent.eventTriggerID.
     *  @param noteOnType Dispatching event type at note on. 0=no events, 1=NOTE_ON_FRAME, 2=NOTE_ON_STREAM, 3=both.
     *  @param noteOffType Dispatching event type at note off. 0=no events, 1=NOTE_OFF_FRAME, 2=NOTE_OFF_STREAM, 3=both.
     *  @see org.si.sion.events.SiONTrackEvent
     */
    public function setEventTrigger(id : Int, noteOnType : Int = 1, noteOffType : Int = 0) : Void
    {
        _eventTriggerID = id;
        _eventTriggerTypeOn = noteOnType;
        _eventTriggerTypeOff = noteOffType;
        _callbackBeforeNoteOn = (noteOnType != 0) ? _eventTriggerOn : null;
        _callbackBeforeNoteOff = (noteOffType != 0) ? _eventTriggerOff : null;
    }
    
    
    /** dispatch note on event once (%e) 
     *  @param id Event trigger ID of this track. This value can be refered from SiONTrackEvent.eventTriggerID.
     *  @param noteOnType Dispatching event type at note on. 0=no events, 1=NOTE_ON_FRAME, 2=NOTE_ON_STREAM, 3=both.
     *  @see org.si.sion.events.SiONTrackEvent
     */
    public function dispatchNoteOnEvent(id : Int, noteOnType : Int = 1) : Void
    {
        if (noteOnType != 0) {
            var currentTID : Int = _eventTriggerID;
            var currentType : Int = _eventTriggerTypeOn;
            _eventTriggerID = id;
            _eventTriggerTypeOn = noteOnType;
            _eventTriggerOn(this);
            _eventTriggerID = currentTID;
            _eventTriggerTypeOn = currentType;
        }
    }
    
    
    /** set envelop step (&#64;fps)
     *  @param fps Frame par second
     */
    public function setEnvelopFPS(fps : Int) : Void
    {
        _env_internval = Math.floor(SiOPMTable.instance.rate / fps);
    }
    
    
    /** release sweep (2nd argument of "s")
     *  @param sweep sweeping speed
     */
    public function setReleaseSweep(sweep : Int) : Void
    {
        _set_sweep_step[0] = sweep << FIXED_BITS;
        _set_sweep_end[0] = ((sweep < 0)) ? 0 : SWEEP_MAX;
        if (sweep != 0) {
            _pns_or[0] = true;
            _envelopOn(0);
        }
        else {
            _envelopOff(0);
        }
    }
    
    
    /** amplitude/pitch modulation envelop (ma, mp) 
     *  @param isPitchMod The command is 'ma' or 'mp'.
     *  @param depth start modulation depth (same as 1st argument)
     *  @param end_depth end modulation depth (same as 2nd argument)
     *  @param delay changing delay (same as 3rd argument)
     *  @param term changing term (same as 4th argument)
     */
    public function setModulationEnvelop(isPitchMod : Bool, depth : Int, end_depth : Int, delay : Int, term : Int) : Void
    {
        // select table
        var table : Array<SLLint> = ((isPitchMod)) ? _table_env_mp : _table_env_ma;
        
        // free previous table
        if (table[1] != null)  SLLint.freeList(table[1]);
        
        if ((0 <= depth && depth < end_depth) || (depth < 0 && depth > end_depth)) {
            // make table and envelop on
            table[1] = _makeModulationTable(depth, end_depth, delay, term);
            _envelopOn(1);
        }
        else {
            // free table and envelop off
            table[1] = null;
            if (isPitchMod)                 channel.setPitchModulation(depth)
            else channel.setAmplitudeModulation(depth);
            _envelopOff(1);
        }
    }
    
    
    /** set tone envelop (&#64;&#64;, _&#64;&#64;) 
     *  @param noteOn 1 for normal envelop, 0 for not-off envelop.
     *  @param table table SiMMLEnvelopTable
     *  @param step envelop speed (same as 2nd argument)
     */
    public function setToneEnvelop(noteOn : Int, table : SiMMLEnvelopTable, step : Int) : Void
    {
        if (table == null || step == 0) {
            _set_env_voice[noteOn] = null;
            _envelopOff(noteOn);
        }
        else {
            _set_env_voice[noteOn] = table.head;
            _set_cnt_voice[noteOn] = step;
            _envelopOn(noteOn);
        }
    }
    
    
    /** set amplitude envelop (na, _na) 
     *  @param noteOn 1 for normal envelop, 0 for not-off envelop.
     *  @param table table SiMMLEnvelopTable
     *  @param step envelop speed (same as 2nd argument)
     *  @param offset true for relative control (!na command), false for absolute control.
     */
    public function setAmplitudeEnvelop(noteOn : Int, table : SiMMLEnvelopTable, step : Int, offset : Bool = false) : Void
    {
        if (table == null || step == 0) {
            _set_env_exp[noteOn] = null;
            _envelopOff(noteOn);
        }
        else {
            _set_env_exp[noteOn] = table.head;
            _set_cnt_exp[noteOn] = step;
            _set_exp_offset[noteOn] = offset;
            _envelopOn(noteOn);
        }
    }
    
    
    /** set filter envelop (nf, _nf)
     *  @param noteOn 1 for normal envelop, 0 for not-off envelop.
     *  @param table table SiMMLEnvelopTable
     *  @param step envelop speed (same as 2nd argument)
     */
    public function setFilterEnvelop(noteOn : Int, table : SiMMLEnvelopTable, step : Int) : Void
    {
        if (table == null || step == 0) {
            _set_env_filter[noteOn] = null;
            _envelopOff(noteOn);
        }
        else {
            _set_env_filter[noteOn] = table.head;
            _set_cnt_filter[noteOn] = step;
            _envelopOn(noteOn);
        }
    }
    
    
    /** set pitch envelop (np, _np)
     *  @param noteOn 1 for normal envelop, 0 for not-off envelop.
     *  @param table table SiMMLEnvelopTable
     *  @param step envelop speed (same as 2nd argument)
     */
    public function setPitchEnvelop(noteOn : Int, table : SiMMLEnvelopTable, step : Int) : Void
    {
        if (table == null || step == 0) {
            _set_env_pitch[noteOn] = _env_zero_table;
            _envelopOff(noteOn);
        }
        else {
            _set_env_pitch[noteOn] = table.head;
            _set_cnt_pitch[noteOn] = step;
            _pns_or[noteOn] = true;
            _envelopOn(noteOn);
        }
    }
    
    
    /** set note envelop (nt, _nt)
     *  @param noteOn 1 for normal envelop, 0 for not-off envelop.
     *  @param table table SiMMLEnvelopTable
     *  @param step envelop speed (same as 2nd argument)
     */
    public function setNoteEnvelop(noteOn : Int, table : SiMMLEnvelopTable, step : Int) : Void
    {
        if (table == null || step == 0) {
            _set_env_note[noteOn] = _env_zero_table;
            _envelopOff(noteOn);
        }
        else {
            _set_env_note[noteOn] = table.head;
            _set_cnt_note[noteOn] = step;
            _pns_or[noteOn] = true;
            _envelopOn(noteOn);
        }
    }
    
    
    
    
    //====================================================================================================
    // Internal uses
    //====================================================================================================
    // initialize / reset
    //--------------------------------------------------
    /** @private [internal] initialize track. [NOTE] Have to call reset() after this. */
    @:allow(org.si.sion.sequencer)
    private function _initialize(seq : MMLSequence, fps : Int, internalTrackID : Int,
                                 eventTriggerOn : SiMMLTrack->Bool, eventTriggerOff : SiMMLTrack->Bool,
                                 isDisposable : Bool) : SiMMLTrack
    {
        _internalTrackID = internalTrackID;
        _isDisposable = isDisposable;
        _defaultFPS = fps;
        _eventTriggerOn = eventTriggerOn;
        _eventTriggerOff = eventTriggerOff;
        _eventTriggerID = -1;
        _eventTriggerTypeOn = 0;
        _eventTriggerTypeOff = 0;
        _mmlData = ((seq != null)) ? (try cast(seq._owner, SiMMLData) catch(e:Dynamic) null) : null;
        executor.initialize(seq);
        
        return this;
    }
    
    
    /** @private [internal] reset track. */
    @:allow(org.si.sion.sequencer)
    private function _reset(bufferIndex : Int) : Void
    {
        trace( 'SiMMLTrack resetting track!!', bufferIndex );
        var i : Int;
        
        // channel module setting
        _channelModuleSetting = _table.channelModuleSetting[SiMMLTable.MT_PSG];
        _simulator = _table.simulators[SiMMLTable.MT_PSG];
        _channelNumber = 0;

        // initialize channel by channel settings
        if (_mmlData != null) {
            _vcommandShift = _mmlData.defaultVCommandShift;
            _velocityMode = _mmlData.defaultVelocityMode;
            _expressionMode = _mmlData.defaultExpressionMode;
        }
        else {
            _vcommandShift = 4;
            _velocityMode = SiOPMTable.VM_LINEAR;
            _expressionMode = SiOPMTable.VM_LINEAR;
        }
        trace('SiMMLTrack : initialized channel by channel settings');
        _velocity = 256;
        _expression = 128;
        _pitchBend = 0;
        _note = -1;
        channel = null;
        _voiceIndex = _channelModuleSetting.initializeTone(this, INT_MIN_VALUE, bufferIndex);
        trace('SiMMLTrack initialized tone');
        //_voiceIndex = _simulator.initializeTone(this, int.MIN_VALUE, bufferIndex);
        var tlTables : Array<Array<Int>> = SiOPMTable.instance.eg_tlTables;
        channel.setVolumeTables(tlTables[_velocityMode], tlTables[_expressionMode]);
        trace('SiMMLTrack set volume tables...');
        // initialize parameters
        noteShift = 0;
        pitchShift = 0;
        _keyOnCounter = 0;
        _keyOnLength = 0;
        _flagNoKeyOn = false;
        _processMode = NORMAL;
        _trackStartDelay = 0;
        _trackStopDelay = 0;
        _stopWithReset = false;
        keyOnDelay = 0;
        quantRatio = 1;
        quantCount = 0;
        eventMask = NO_MASK;
        _env_pitch_active = false;
        _pitchIndex = 0;
        _sweep_pitch = 0;
        _env_exp_offset = 0;
        setEnvelopFPS(_defaultFPS);
        _callbackBeforeNoteOn = null;
        _callbackBeforeNoteOff = null;
        _callbackUpdateRegister = _defaultUpdateRegister;
        _residue = 0;
        _priority = 0;
        _env_exp = null;
        _env_voice = null;
        _env_note = _env_zero_table;
        _env_pitch = _env_zero_table;
        _env_filter = null;
        _env_ma = null;
        _env_mp = null;

        // reset envelop tables
        for (i in 0...2){
            _set_processMode[i] = NORMAL;
            _set_env_exp[i] = null;
            _set_env_voice[i] = null;
            _set_env_note[i] = _env_zero_table;
            _set_env_pitch[i] = _env_zero_table;
            _set_env_filter[i] = null;
            _pns_or[i] = false;
            _set_exp_offset[i] = false;
            _set_cnt_exp[i] = 1;
            _set_cnt_voice[i] = 1;
            _set_cnt_note[i] = 1;
            _set_cnt_pitch[i] = 1;
            _set_cnt_filter[i] = 1;
            _set_sweep_step[i] = 0;
            _set_sweep_end[i] = 0;
            _table_env_ma[i] = null;
            _table_env_mp[i] = null;
        }
        trace('SiMMLTrack nothing stands out yet');
         // reset pointer
        executor.resetPointer();
    }
    
    
    /** @private [internal] reset volume offset. */
    public function _resetVolumeOffset() : Void
    {
        channel.offsetVolume(_expression, _velocity);
    }
    
    
    
    
    // processing
    //--------------------------------------------------
    /** @private [internal] prepare buffer. this is called from SiMMLSequencer.process()/dummyProcess(). */
    @:allow(org.si.sion.sequencer)
    private function _prepareBuffer(bufferingLength : Int) : Int
    {
        // register all tables
        if (_mmlData != null)             _mmlData._registerAllTables()
        else {  // clear all stencil tables  
            SiOPMTable._instance.samplerTables[0].stencil = null;
            SiOPMTable._instance._stencilCustomWaveTables = null;
            SiOPMTable._instance._stencilPCMVoices = null;
            _table._stencilEnvelops = null;
            _table._stencilVoices = null;
        }  // no delay, usually  
        
        
        
        if (_trackStartDelay == 0) {
            return bufferingLength;
        }  // wait for starting sound  
        
        
        
        if (bufferingLength <= _trackStartDelay) {
            _trackStartDelay -= bufferingLength;
            return 0;
        }  // start sound in this frame  
        
        
        
        var len : Int = bufferingLength - _trackStartDelay;
        channel.nop(_trackStartDelay);
        _trackStartDelay = 0;
        
        _priority++;
        
        return len;
    }
    
    
    /** @private [internal] buffering */
    @:allow(org.si.sion.sequencer)
    private function _buffer(length : Int) : Void
    {
        // Converted from the original AS3 function $()
        // processing inside
        function dlr(procLen : Int) : Void {
            switch (_processMode)
            {
                case NORMAL:channel.buffer(procLen);
                case ENVELOP:_residue = _bufferEnvelop(procLen, _residue);
            }
        };

        // check track stopping
        var trackStop : Bool = false;
        var trackStopResume : Int = 0;
        if (_trackStopDelay > 0) {
            if (_trackStopDelay > length) {
                _trackStopDelay -= length;
            }
            else {
                trackStopResume = length - _trackStopDelay;
                trackStop = true;
                length = _trackStopDelay;
                _trackStopDelay = 0;
            }
        }

        // buffering
        if (_keyOnCounter == 0) {
            // no status changing
            dlr(length);
        }
        else 
        if (_keyOnCounter > length) {
            // decrement _keyOnCounter
            dlr(length);
            _keyOnCounter -= length;
        }
        else {
            // process -> toggle key -> process
            length -= _keyOnCounter;
            dlr(_keyOnCounter);
            _toggleKey();
            if (length > 0) {
                dlr(length);
            }
        }

        // track stopped
        if (trackStop) {
            if (executor.pointer != null) {
                executor.stop();
                if (_stopWithReset) {
                    _keyOff();
                    _note = -1;
                    channel.reset();
                }
            }
            else if (channel.isNoteOn) {
                _keyOff();
                _note = -1;
                if (_stopWithReset) {
                    channel.reset();
                }
            }
            if (trackStopResume > 0) {
                dlr(trackStopResume);
            }
        }
    }
    
    
    // buffering with table envelops
    private function _bufferEnvelop(length : Int, step : Int) : Int
    {
        var x : Int;
        
        while (length >= step){
            // processing
            if (step > 0)                 channel.buffer(step);


            // change expression
            if (_env_exp != null && --_cnt_exp == 0) {
                x = _env_exp_offset + _env_exp.i;
                if (x < 0) {x = 0;
                }
                else if (x > 128) {x = 128;
                }
                channel.offsetVolume(x, _velocity);
                _env_exp = _env_exp.next;
                _cnt_exp = _max_cnt_exp;
            }  // change pitch/note  
            
            
            
            if (_env_pitch_active) {
                channel.pitch = _env_pitch.i + (_env_note.i << 6) + (_sweep_pitch >> FIXED_BITS);
                // pitch envelop
                if (--_cnt_pitch == 0) {
                    _env_pitch = _env_pitch.next;
                    _cnt_pitch = _max_cnt_pitch;
                }  // note envelop  
                
                if (--_cnt_note == 0) {
                    _env_note = _env_note.next;
                    _cnt_note = _max_cnt_note;
                }  // sweep  
                
                _sweep_pitch += _sweep_step;
                if (_sweep_step > 0) {
                    if (_sweep_pitch > _sweep_end) {
                        _sweep_pitch = _sweep_end;
                        _sweep_step = 0;
                    }
                }
                else {
                    if (_sweep_pitch < _sweep_end) {
                        _sweep_pitch = _sweep_end;
                        _sweep_step = 0;
                    }
                }
            }  // change filter  
            
            
            
            if (_env_filter != null && --_cnt_filter == 0) {
                channel.offsetFilter(_env_filter.i);
                _env_filter = _env_filter.next;
                _cnt_filter = _max_cnt_filter;
            }  // change tone  
            
            
            
            if (_env_voice != null && --_cnt_voice == 0) {
                _channelModuleSetting.selectTone(this, _env_voice.i);
                //_simulator.selectTone(this, _env_voice.i);
                _env_voice = _env_voice.next;
                _cnt_voice = _max_cnt_voice;
            }  // change modulations  
            
            
            
            if (_env_ma != null) {
                channel.setAmplitudeModulation(_env_ma.i);
                _env_ma = _env_ma.next;
            }
            if (_env_mp != null) {
                channel.setPitchModulation(_env_mp.i);
                _env_mp = _env_mp.next;
            }  // index increment  
            
            
            
            length -= step;
            step = _env_internval;
        }  // rest process  
        
        
        
        if (length > 0)             channel.buffer(length);

        // next rest length
        
        return _env_internval - length;
    }
    
    
    
    
    // key on/off
    //--------------------------------------------------
    // toggle note
    private function _toggleKey() : Void
    {
        if (channel.isNoteOn) {
            _keyOff();
        }
        else {
            _keyOn();
        }
    }
    
    
    // note on
    private function _keyOn() : Void
    {
        // callback
        if (_callbackBeforeNoteOn != null) {
            if (!_callbackBeforeNoteOn(this))                 return;
        }

        // change pitch
        var oldPitch : Int = channel.pitch;
        _pitchIndex = ((_note + noteShift) << 6) + pitchShift;
        channel.pitch = _pitchIndex + _pitchBend;

        // note on
        if (!_flagNoKeyOn) {
            // reset previous envelop
            if (_processMode == ENVELOP) {
                channel.offsetVolume(_expression, _velocity);
                _channelModuleSetting.selectTone(this, _voiceIndex);
                //_simulator.selectTone(this, _voiceIndex);
                channel.offsetFilter(128);
            }  // previous note off  

            if (channel.isNoteOn) {
                // callback
                if (_callbackBeforeNoteOff != null)                     _callbackBeforeNoteOff(this);
                channel.noteOff();
            }  // update process  

            _updateProcess(1);

            // note on
            channel.noteOn();
        }
        else {
            // portament
            if (_set_sweep_step[1] > 0) {
                channel.pitch = oldPitch;
                _sweep_step = Math.round(((_pitchIndex - oldPitch) << FIXED_BITS) / _set_sweep_step[1]);
                _sweep_end = _pitchIndex << FIXED_BITS;
                _sweep_pitch = oldPitch << FIXED_BITS;
            }
            else {
                _sweep_pitch = channel.pitch << FIXED_BITS;
            }  // try to set envelop off  

            _envelopOff(1);
        }

        _flagNoKeyOn = false;
        
        // set key on counter
        _keyOnCounter = _keyOnLength;
    }
    
    
    // note off
    private function _keyOff() : Void
    {
        // callback
        if (_callbackBeforeNoteOff != null) {
            if (!_callbackBeforeNoteOff(this))                 return;
        }  // note off  
        
        
        
        channel.noteOff();
        // no key off after this
        _keyOnCounter = 0;
        // update process
        _updateProcess(0);
        // priority down
        _priority += 32;
    }
    
    
    private function _updateProcess(keyOn : Int) : Void
    {
        // prepare next process
        _processMode = _set_processMode[keyOn];

        if (_processMode == ENVELOP) {
            // set envelop tables
            _env_exp = _set_env_exp[keyOn];
            _env_voice = _set_env_voice[keyOn];
            _env_note = _set_env_note[keyOn];
            _env_pitch = _set_env_pitch[keyOn];
            _env_filter = _set_env_filter[keyOn];
            // set envelop counters
            _max_cnt_exp = _set_cnt_exp[keyOn];
            _max_cnt_voice = _set_cnt_voice[keyOn];
            _max_cnt_note = _set_cnt_note[keyOn];
            _max_cnt_pitch = _set_cnt_pitch[keyOn];
            _max_cnt_filter = _set_cnt_filter[keyOn];
            _cnt_exp = 1;
            _cnt_voice = 1;
            _cnt_note = 1;
            _cnt_pitch = 1;
            _cnt_filter = 1;
            // set modulation envelops
            _env_ma = _table_env_ma[keyOn];
            _env_mp = _table_env_mp[keyOn];
            // set sweep
            _sweep_step = ((keyOn != 0)) ? 0 : _set_sweep_step[keyOn];
            _sweep_end = ((keyOn != 0)) ? 0 : _set_sweep_end[keyOn];
            // set pitch values
            _sweep_pitch = channel.pitch << FIXED_BITS;
            _env_exp_offset = ((_set_exp_offset[keyOn])) ? _expression : 0;
            _env_pitch_active = _pns_or[keyOn];

            // activate filter
            if (!channel.isFilterActive)
                channel.activateFilter(_env_filter != null);

            // reset index
            _residue = 0;
        }
    }
    
    
    
    
    // event handlers
    //--------------------------------------------------
    /** @private [internal] handler for MMLEvent.REST. */
    @:allow(org.si.sion.sequencer)
    private function _onRestEvent() : Void
    {
        _flagNoKeyOn = false;
    }
    
    
    /** @private [internal] handler for MMLEvent.NOTE. */
    @:allow(org.si.sion.sequencer)
    private function _onNoteEvent(note : Int, length : Int) : Void
    {
        _keyOnLength = Math.floor(length * quantRatio) - quantCount - keyOnDelay;
        if (_keyOnLength < 1)
            _keyOnLength = 1;
        _mmlKeyOn(note);
    }
    
    
    /** @private [internal] Slur without next notes key on. This have to be called just after keyOn(). */
    @:allow(org.si.sion.sequencer)
    private function _onSlur() : Void
    {
        _flagNoKeyOn = true;
        _keyOnCounter = 0;
    }
    
    
    /** @private [internal] Slur with next notes key on. This have to be called just after keyOn(). */
    @:allow(org.si.sion.sequencer)
    private function _onSlurWeak() : Void
    {
        _keyOnCounter = 0;
    }
    
    
    /** @private [internal] Set pitch bend (and slur) immediately. This function called from pitchBend() and '*' command.
     *  @param nextNote The 2nd note to intergradate.
     *  @param term bending time in sample count.
     */
    @:allow(org.si.sion.sequencer)
    private function _onPitchBend(nextNote : Int, term : Int) : Void
    {
        var startPitch : Int = channel.pitch;
        var endPitch : Int = (nextNote + noteShift) << 6;
        if (endPitch == 0) {
            endPitch = (startPitch & 63) + pitchShift;
        }
        _onSlur();
        if (startPitch == endPitch)             return;
        
        _sweep_step = Math.floor(((endPitch - startPitch) << FIXED_BITS) * _env_internval / term);
        _sweep_end = endPitch << FIXED_BITS;
        _sweep_pitch = startPitch << FIXED_BITS;
        _env_pitch_active = true;
        _env_note = _set_env_note[1];
        _env_pitch = _set_env_pitch[1];
        
        _processMode = ENVELOP;
    }
    
    
    /** @private [internal] change note length. call from SiMMLSequence._onSlur()/_onSlurWeek() when its masked. */
    @:allow(org.si.sion.sequencer)
    private function _changeNoteLength(length : Int) : Void
    {
        _keyOnCounter = Math.floor(length * quantRatio) - quantCount - keyOnDelay;
        if (_keyOnCounter < 1)             _keyOnCounter = 1;
    }
    
    
    /** @praivate [internal use] Channel parameters (&#64;) */
    @:allow(org.si.sion.sequencer)
    private function _setChannelParameters(param : Array<Int>) : MMLSequence
    {
        var ret : MMLSequence = null;
        if (param[0] != INT_MIN_VALUE) {
            ret = _channelModuleSetting.selectTone(this, param[0]);
            //ret = _simulator.selectTone(this, param[0]);
            _voiceIndex = param[0];
        }
        channel.setParameters(param);
        return ret;
    }
    
    /** @private [internal use] mml v command */
    @:allow(org.si.sion.sequencer)
    private function _mmlVCommand(v : Int) : Void
    {
        velocity = v << _vcommandShift;
    }
    
    /** @private [internal use] mml v command */
    @:allow(org.si.sion.sequencer)
    private function _mmlVShift(v : Int) : Void
    {
        velocity += v << _vcommandShift;
    }
    
    // update register
    private function _defaultUpdateRegister(addr : Int, data : Int) : Void
    {
        channel.setRegister(addr, data);
    }
    
    
    // mml key on
    private function _mmlKeyOn(note : Int) : Void
    {
        _note = note;
        _trackStartDelay = 0;
        if (keyOnDelay != 0) {
            _keyOff();
            _keyOnCounter = keyOnDelay;
        }
        else {
            _keyOn();
        }
    }
    
    
    // internal functions
    //--------------------------------------------------
    // envelop off
    private function _envelopOff(noteOn : Int) : Void
    {
        // update (pitch || note || sweep)
        if (_set_sweep_step[noteOn] == 0 &&
            _set_env_pitch[noteOn] == _env_zero_table &&
            _set_env_note[noteOn] == _env_zero_table) 
        {
            _pns_or[noteOn] = false;
        }  // all envelops are off -> update processMode  
        
        
        
        if ( _pns_or[noteOn] &&
            (_table_env_ma[noteOn] == null) &&
            (_table_env_mp[noteOn] == null) &&
            (_set_env_exp[noteOn] == null) &&
            (_set_env_filter[noteOn] == null) &&
            (_set_env_voice[noteOn] == null))
        {
            _set_processMode[noteOn] = NORMAL;
        }
    }
    
    
    // envelop on
    private function _envelopOn(noteOn : Int) : Void
    {
        _set_processMode[noteOn] = ENVELOP;
    }
    
    
    // make modulation table
    private function _makeModulationTable(depth : Int, end_depth : Int, delay : Int, term : Int) : SLLint
    {
        // initialize
        var list : SLLint = SLLint.allocList(delay + term + 1);
        var i : Int;
        var elem : SLLint;
        var step : Int;
        
        // delay
        elem = list;
        if (delay != 0) {
            i = 0;
            while (i < delay){
                elem.i = depth;
                i++;
                elem = elem.next;
            }
        }  // changing  
        
        if (term != 0) {
            depth <<= FIXED_BITS;
            step = Math.round(((end_depth << FIXED_BITS) - depth) / term);
            i = 0;
            while (i < term){
                elem.i = (depth >> FIXED_BITS);
                depth += step;
                i++;
                elem = elem.next;
            }
        }  // last data  
        
        elem.i = end_depth;
        
        return list;
    }
}


