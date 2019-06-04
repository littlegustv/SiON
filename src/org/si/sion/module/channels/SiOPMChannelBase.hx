//----------------------------------------------------------------------------------------------------
// SiOPM sound channel base class
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.sion.module.channels;

import org.si.utils.SLLint;
import org.si.utils.SLLNumber;
import org.si.sion.module.*;


/** SiOPM sound channel base class. <br/>
 *  The SiOPM sound channels generate wave data and write it into streaming buffer.
 */
class SiOPMChannelBase
{
    public var masterVolume(get, set) : Int;
    public var pan(get, set) : Int;
    public var mute(get, set) : Bool;
    public var activeOperatorIndex(never, set) : Int;
    public var rr(never, set) : Int;
    public var tl(never, set) : Int;
    public var fmul(never, set) : Int;
    public var phase(never, set) : Int;
    public var detune(never, set) : Int;
    public var fixedPitch(never, set) : Int;
    public var ssgec(never, set) : Int;
    public var erst(never, set) : Bool;
    public var pitch(get, set) : Int;
    public var bufferIndex(get, never) : Int;
    public var isNoteOn(get, never) : Bool;
    public var isIdling(get, never) : Bool;
    public var isFilterActive(get, never) : Bool;
    public var filterType(get, set) : Int;
    public var channelType(get, never) : Int;

    // constants
    //--------------------------------------------------
    /** standard output */
    public static var OUTPUT_STANDARD : Int = 0;
    /** overwrite pipe  */
    public static inline var OUTPUT_OVERWRITE : Int = 1;
    /** add to pipe     */
    public static inline var OUTPUT_ADD : Int = 2;
    
    /** no input from pipe  */
    public var INPUT_ZERO : Int = 0;
    /** input from pipe     */
    public static inline var INPUT_PIPE : Int = 1;
    /** input from feedback */
    public var INPUT_FEEDBACK : Int = 2;
    
    /** low pass filter */
    public static inline var FILTER_LP : Int = 0;
    /** band pass filter */
    public static inline var FILTER_BP : Int = 1;
    /** high pass filter */
    public static inline var FILTER_HP : Int = 2;
    
    // LPF envelop status
    private static inline var EG_ATTACK : Int = 0;
    private static inline var EG_DECAY1 : Int = 1;
    private static inline var EG_DECAY2 : Int = 2;
    private static inline var EG_SUSTAIN : Int = 3;
    private static inline var EG_RELEASE : Int = 4;
    private static inline var EG_OFF : Int = 5;

    private static inline var INT_MAX_VALUE = 2147483647;
    private static inline var INT_MIN_VALUE = -2147483648;

    // variables
    //--------------------------------------------------
    /** table */
    public var _table : SiOPMTable;
    /** chip */
    private var _chip : SiOPMModule;
    /** functor to process */
    private var _funcProcess : Int->Void;
    /** note on flag */
    private var _isNoteOn : Bool;
    
    // Pipe buffer
    /** buffering index */private var _bufferIndex : Int;
    /** input level */private var _inputLevel : Int;
    /** ringmod level */private var _ringmodLevel : Float;
    /** input level */private var _inputMode : Int;
    /** output mode */private var _outputMode : Int;
    /** in pipe */private var _inPipe : SLLint;
    /** ringmod pipe */private var _ringPipe : SLLint;
    /** base pipe */private var _basePipe : SLLint;
    /** out pipe */private var _outPipe : SLLint;
    
    // volume and stream
    /** stream */private var _streams : Array<SiOPMStream>;
    /** volume */private var _volumes : Array<Float>;
    /** idling flag */private var _isIdling : Bool;
    /** pan */private var _pan : Int;
    /** effect send flag */private var _hasEffectSend : Bool;
    /** mute */private var _mute : Bool;
    /** veocity table */private var _veocityTable : Array<Int>;
    /** expression table */private var _expressionTable : Array<Int>;
    
    // LPFilter
    /** filter switch */private var _filterOn : Bool;
    /** filter type */private var _filterType : Int;
    /** cutoff frequency */private var _cutoff : Int = 0;
    /** cutoff frequency */private var _cutoff_offset : Int;
    /** resonance */private var _resonance : Float;
    /** filter Variables */private var _filterVriables : Array<Float>;
    /** eg step residue */private var _prevStepRemain : Int;
    /** eg step */private var _filter_eg_step : Int;
    /** eg phase shift l.*/private var _filter_eg_next : Int;
    /** eg direction */private var _filter_eg_cutoff_inc : Int;
    /** eg state */private var _filter_eg_state : Int;
    /** eg rate */private var _filter_eg_time : Array<Int>;
    /** eg level */private var _filter_eg_cutoff : Array<Int>;
    
    // Low frequency oscillator
    /** frequency ratio */private var _freq_ratio : Int;
    /** lfo switch */private var _lfo_on : Int = 0;
    /** lfo timer */private var _lfo_timer : Int;
    /** lfo timer step */private var _lfo_timer_step : Int;
    /** lfo step buffer */private var _lfo_timer_step_ : Int;
    /** lfo phase */private var _lfo_phase : Int;
    /** lfo wave table */private var _lfo_waveTable : Array<Int>;
    /** lfo wave shape */private var _lfo_waveShape : Int;
    
    
    // constructor
    //--------------------------------------------------
    /** Constructor @param chip Managing SiOPMModule. */
    @:allow(SiOPMChannelManager) // For some reason this doesn't seem to work
    public function new(chip : SiOPMModule)
    {
        _table = SiOPMTable.instance;
        _chip = chip;
        _isFree = true;
        
        _filterVriables = new Array<Float>();
        _streams = new Array<SiOPMStream>();
        _volumes = new Array<Float>();
        _filter_eg_time = new Array<Int>();
        _filter_eg_cutoff = new Array<Int>();

        _funcProcess = _nop;
    }


    // interfaces
    //--------------------------------------------------
    /** Set by SiOPMChannelParam. */
    public function setSiOPMChannelParam(param : SiOPMChannelParam, withVolume : Bool, withModulation : Bool = true) : Void
    {
    }

    /** Get SiOPMChannelParam. */
    public function getSiOPMChannelParam(param : SiOPMChannelParam) : Void
    {
    }

    /** Set wave data. */
    public function setWaveData(waveData : SiOPMWaveBase) : Void
    {
    }
    
    /** channel number (2nd argument of %) */
    public function setChannelNumber(channelNum : Int) : Void
    {
    }

    /** algorism (&#64;al) */
    public function setAlgorism(cnt : Int, alg : Int) : Void
    {
    }
    /** feedback (&#64;fb) */
    public function setFeedBack(fb : Int, fbc : Int) : Void
    {
    }
    /** parameters (&#64; call from SiMMLTrack._setChannelParameters()) */
    public function setParameters(param : Array<Int>) : Void
    {
    }
    /** pgType and ptType (&#64; call from SiMMLChannelSetting.selectTone()/initializeTone()) */
    public function setType(pgType : Int, ptType : Int) : Void
    {
    }
    /** Attack rate */
    public function setAllAttackRate(ar : Int) : Void
    {
    }
    /** Release rate (s) */
    public function setAllReleaseRate(rr : Int) : Void
    {
    }
    
    /** Master volume (0-128) */
    private function get_masterVolume() : Int {
        return Math.floor(_volumes[0] * 128);
    }
    private function set_masterVolume(v : Int) : Int {
        v = ((v < 0)) ? 0 : ((v > 128)) ? 128 : v;
        _volumes[0] = v * 0.0078125;
        return v;
    }
    
    /** Pan (-64-64 left=-64, center=0, right=64).<br/>
     *  [left volume]  = cos((pan+64)/128*PI*0.5) * volume;<br/>
     *  [right volume] = sin((pan+64)/128*PI*0.5) * volume;
     */
    private function get_pan() : Int {
        return _pan - 64;
    }
    private function set_pan(p : Int) : Int{
        _pan = ((p < -64)) ? 0 : ((p > 64)) ? 128 : (p + 64);
        return p;
    }
    
    /** Mute */
    private function get_mute() : Bool{return _mute;
    }
    private function set_mute(m : Bool) : Bool{
        _mute = m;
        return m;
    }
    
    
    /** active operator index (i). */
    private function set_activeOperatorIndex(i : Int) : Int{
        return i;
    }
    /** Release rate (&#64;rr) */
    private function set_rr(r : Int) : Int{
        return r;
    }
    /** total level (&#64;tl)  */
    private function set_tl(i : Int) : Int{
        return i;
    }
    /** fine multiple (&#64;ml)  */
    private function set_fmul(i : Int) : Int{
        return i;
    }
    /** phase (&#64;ph) */
    private function set_phase(i : Int) : Int{
        return i;
    }
    /** detune (&#64;dt) */
    private function set_detune(i : Int) : Int{
        return i;
    }
    /** fixed pitch (&#64;fx) */
    private function set_fixedPitch(i : Int) : Int{
        return i;
    }
    /** ssgec (&#64;se) */
    private function set_ssgec(i : Int) : Int{
        return i;
    }
    /** envelop reset (&#64;er) */
    private function set_erst(b : Bool) : Bool{
        return b;
    }
    
    /** pitch */
    private function get_pitch() : Int{return 0;
    }
    private function set_pitch(i : Int) : Int{
        return i;
    }
    
    /** buffer index */
    private function get_bufferIndex() : Int{return _bufferIndex;
    }
    
    /** is this channel note on ? */
    private function get_isNoteOn() : Bool{return _isNoteOn;
    }
    
    /** Is idling ? */
    private function get_isIdling() : Bool{return _isIdling;
    }
    
    /** Is filter active ? */
    private function get_isFilterActive() : Bool{return _filterOn;
    }
    
    
    /** filter mode */
    private function get_filterType() : Int{return _filterType;
    }
    private function set_filterType(mode : Int) : Int
    {
        _filterType = ((mode < 0 || mode > 2)) ? 0 : mode;
        return mode;
    }
    
    
    
    
    // volume control
    //--------------------------------------------------
    /** set all stream send levels by Vector.&lt;int&gt;.
     *  @param param Vector.&lt;int&gt;(8) of all volumes[0-128].
     */
    public function setAllStreamSendLevels(param : Array<Int>) : Void
    {
        var i : Int;
        var imax : Int = SiOPMModule.STREAM_SEND_SIZE;
        var v : Int;
        for (i in 0...imax){
            v = param[i];
            _volumes[i] = ((v != INT_MIN_VALUE)) ? (v * 0.0078125) : 0;
        }
        for (i in 0...imax){
            if (_volumes[i] > 0)                 _hasEffectSend = true;
        }
    }
    
    
    /** set stream buffer.
     *  @param streamNum stream number[0-7]. The streamNum of 0 means master stream.
     *  @param stream stream buffer instance. Set null to set as default.
     */
    public function setStreamBuffer(streamNum : Int, stream : SiOPMStream = null) : Void
    {
        _streams[streamNum] = stream;
    }
    
    
    /** set stream send.
     *  @param streamNum stream number[0-7]. The streamNum of 0 means master volume.
     *  @param volume send level[0-1].
     */
    public function setStreamSend(streamNum : Int, volume : Float) : Void
    {
        _volumes[streamNum] = volume;
        if (streamNum == 0)             return;
        if (volume > 0)             _hasEffectSend = true
        else {
            var i : Int;
            var imax : Int = SiOPMModule.STREAM_SEND_SIZE;
            for (i in 0...imax){
                if (_volumes[i] > 0)                     _hasEffectSend = true;
            }
        }
    }
    
    
    /** get stream send.
     *  @param streamNum stream number[0-7]. The streamNum of 0 means master volume.
     *  @return send level[0-1].
     */
    public function getStreamSend(streamNum : Int) : Float
    {
        return _volumes[streamNum];
    }
    
    
    /** offset volume, controled by SiMMLTrack. */
    public function offsetVolume(expression : Int, velocity : Int) : Void
    {
        
    }
    
    
    
    
    // LFO control
    //--------------------------------------------------
    /** set chip "PSEUDO" frequency ratio by [%] (&#64;clock). */
    public function setFrequencyRatio(ratio : Int) : Void
    {
        _freq_ratio = ratio;
    }
    
    
    /** initialize LFO (&#64;lfo). 
     *  @param waveform waveform number, -1 to set customized wave table
     *  @param customWaveTable customized wave table, the length is 256 and the values are limited in the range of 0-255. This argument is available when waveform=-1.
     */
    public function initializeLFO(waveform : Int, customWaveTable : Array<Int> = null) : Void
    {
        if (waveform == -1 && customWaveTable != null && customWaveTable.length == 256) {
            _lfo_waveShape = -1;
            _lfo_waveTable = customWaveTable;
        }
        else {
            _lfo_waveShape = ((0 <= waveform && waveform <= SiOPMTable.LFO_WAVE_MAX)) ? waveform : SiOPMTable.LFO_WAVE_TRIANGLE;
            _lfo_waveTable = _table.lfo_waveTables[_lfo_waveShape];
        }
        _lfo_timer = 1;
        _lfo_timer_step_ = _lfo_timer_step = 0;
        _lfo_phase = 0;
    }
    
    
    /** set LFO cycle time (&#64;lfo). */
    public function setLFOCycleTime(ms : Float) : Void
    {
        _lfo_timer = 0;
        // 0.17294117647058824 = 44100/(1000*255)
        _lfo_timer_step_ = _lfo_timer_step = Math.floor((SiOPMTable.LFO_TIMER_INITIAL / (ms * 0.17294117647058824))) << _table.sampleRatePitchShift;
    }
    
    
    /** amplitude modulation (ma) */
    public function setAmplitudeModulation(depth : Int) : Void{
    }
    
    
    /** pitch modulation (mp) */
    public function setPitchModulation(depth : Int) : Void{
    }
    
    
    
    
    // filter control
    //--------------------------------------------------
    /** Filter activation */
    public function activateFilter(b : Bool) : Void
    {
        _filterOn = b;
    }
    
    
    /** SVFilter envelop (&#64;f).
     *  @param cutoff initial cutoff (0-128).
     *  @param resonance resonance (0-9).
     *  @param ar attack rate (0-63).
     *  @param dr1 decay rate 1 (0-63).
     *  @param dr2 decay rate 2 (0-63).
     *  @param rr release rate (0-63).
     *  @param dc1 decay cutoff level 1 (0-128).
     *  @param dc2 decay cutoff level 2 (0-128).
     *  @param sc sustain cutoff level (0-128).
     *  @param rc release cutoff level (0-128).
     */
    public function setSVFilter(cutoff : Int = 128, resonance : Int = 0, ar : Int = 0, dr1 : Int = 0, dr2 : Int = 0, rr : Int = 0, dc1 : Int = 128, dc2 : Int = 128, sc : Int = 128, rc : Int = 128) : Void
    {
        _filter_eg_cutoff[EG_ATTACK] = ((cutoff < 0)) ? 0 : ((cutoff > 128)) ? 128 : cutoff;
        _filter_eg_cutoff[EG_DECAY1] = ((dc1 < 0)) ? 0 : ((dc1 > 128)) ? 128 : dc1;
        _filter_eg_cutoff[EG_DECAY2] = ((dc2 < 0)) ? 0 : ((dc2 > 128)) ? 128 : dc2;
        _filter_eg_cutoff[EG_SUSTAIN] = ((sc < 0)) ? 0 : ((sc > 128)) ? 128 : sc;
        _filter_eg_cutoff[EG_RELEASE] = 0;
        _filter_eg_cutoff[EG_OFF] = ((rc < 0)) ? 0 : ((rc > 128)) ? 128 : rc;
        _filter_eg_time[EG_ATTACK] = _table.filter_eg_rate[ar & 63];
        _filter_eg_time[EG_DECAY1] = _table.filter_eg_rate[dr1 & 63];
        _filter_eg_time[EG_DECAY2] = _table.filter_eg_rate[dr2 & 63];
        _filter_eg_time[EG_SUSTAIN] = INT_MAX_VALUE;
        _filter_eg_time[EG_RELEASE] = _table.filter_eg_rate[rr & 63];
        _filter_eg_time[EG_OFF] = INT_MAX_VALUE;
        
        var res : Int = ((resonance < 0)) ? 0 : ((resonance > 9)) ? 9 : resonance;
        _resonance = (1 << (9 - res)) * 0.001953125;  // 0.001953125=1/512  
        
        _filterOn = (cutoff < 128 || resonance > 0 || ar > 0 || rr > 0);
    }
    
    
    /** LP Filter cutoff offset controled by table envelop (nf) */
    public function offsetFilter(i : Int) : Void
    {
        _cutoff_offset = i - 128;
    }
    
    
    
    
    // connection control
    //--------------------------------------------------
    /** Set input pipe (&#64;i). 
     *  @param level Input level. The value for a standard FM sound module is 5.
     *  @param pipeIndex Input pipe index (0-3).
     */
    public function setInput(level : Int, pipeIndex : Int) : Void
    {
        // pipe index
        pipeIndex &= 3;
        
        // set pipe
        if (level > 0) {
            _inPipe = _chip.getPipe(pipeIndex, _bufferIndex);
            _inputMode = INPUT_PIPE;
            _inputLevel = level + 10;
        }
        else {
            _inPipe = _chip.zeroBuffer;
            _inputMode = INPUT_ZERO;
            _inputLevel = 0;
        }
    }
    
    
    /** Set ring modulation pipe (&#64;r).
     *  @param level. Input level(0-8).
     *  @param pipeIndex Input pipe index (0-3).
     */
    public function setRingModulation(level : Int, pipeIndex : Int) : Void
    {
        var i : Int;
        
        // pipe index
        pipeIndex &= 3;
        
        // ring modulation level
        _ringmodLevel = level * 4 / (1 << SiOPMTable.LOG_VOLUME_BITS);
        
        // set pipe
        _ringPipe = ((level > 0)) ? _chip.getPipe(pipeIndex, _bufferIndex) : null;
    }
    
    
    /** Set output pipe (&#64;o).
     *  @param outputMode Output mode. 0=standard stereo out, 1=overwrite pipe. 2=add pipe.
     *  @param pipeIndex Output stream/pipe index (0-3).
     */
    public function setOutput(outputMode : Int, pipeIndex : Int) : Void
    {
        var i : Int;
        var flagAdd : Bool;
        
        // pipe index
        pipeIndex &= 3;
        
        // set pipe
        if (outputMode == OUTPUT_STANDARD) {
            pipeIndex = 4;  // pipe[4] is used.  
            flagAdd = false;
        }
        else {
            flagAdd = (outputMode == OUTPUT_ADD);
        }  // output mode  
        
        
        
        _outputMode = outputMode;
        
        // set output pipe
        _outPipe = _chip.getPipe(pipeIndex, _bufferIndex);
        
        // set base pipe
        _basePipe = ((flagAdd)) ? (_outPipe) : (_chip.zeroBuffer);
    }
    
    
    /** set velocity and expression tables
     *  @param vtable volume table (length = 513)
     *  @param xtable expression table (length = 513)
     */
    public function setVolumeTables(vtable : Array<Int>, xtable : Array<Int>) : Void
    {
        _veocityTable = vtable;
        _expressionTable = xtable;
    }
    
    
    
    
    // operations
    //--------------------------------------------------
    /** Initialize. */
    public function initialize(prev : SiOPMChannelBase, bufferIndex : Int) : Void
    {
        // volume
        var i : Int;
        var imax : Int = SiOPMModule.STREAM_SEND_SIZE;
        if (prev != null) {
            for (i in 0...imax){
                _volumes[i] = prev._volumes[i];
                _streams[i] = prev._streams[i];
            }
            _pan = prev._pan;
            _hasEffectSend = prev._hasEffectSend;
            _mute = prev._mute;
            _veocityTable = prev._veocityTable;
            _expressionTable = prev._expressionTable;
        }
        else {
            _volumes[0] = 0.5;
            _streams[0] = null;
            for (i in 0...imax){
                _volumes[i] = 0;
                _streams[i] = null;
            }
            _pan = 64;
            _hasEffectSend = false;
            _mute = false;
            _veocityTable = _table.eg_tlTableLine;
            _expressionTable = _table.eg_tlTableLine;
        }  // buffer index  
        
        
        
        _isNoteOn = false;
        _isIdling = true;
        _bufferIndex = bufferIndex;
        
        // LFO
        initializeLFO(SiOPMTable.LFO_WAVE_TRIANGLE);
        setLFOCycleTime(333);
        setFrequencyRatio(100);
        
        // Connection
        setInput(0, 0);
        setRingModulation(0, 0);
        setOutput(OUTPUT_STANDARD, 0);
        
        // LPFilter
        _filterVriables[0] = _filterVriables[1] = _filterVriables[2] = 0;
        _cutoff_offset = 0;
        _filterType = FILTER_LP;
        setSVFilter();
        shiftSVFilterState(EG_OFF);
    }
    
    
    /** Reset */
    public function reset() : Void
    {
        _isNoteOn = false;
        _isIdling = true;
    }
    
    
    /** Note on */
    public function noteOn() : Void
    {
        _lfo_phase = 0;  // reset lfo phase  
        if (_filterOn) {  // reset envelop  
            resetSVFilterState();
            shiftSVFilterState(EG_ATTACK);
        }
        _isNoteOn = true;
    }
    
    
    /** Note off */
    public function noteOff() : Void
    {
        if (_filterOn) {  // shift filters status  
            shiftSVFilterState(EG_RELEASE);
        }
        _isNoteOn = false;
    }
    
    
    /** set register */
    public function setRegister(addr : Int, data : Int) : Void
    {
        
        
    }
    
    
    
    
    // processing
    //--------------------------------------------------
    /** reset channel buffering status */
    public function resetChannelBufferStatus() : Void
    {
        _bufferIndex = 0;
    }
    
    
    /** Buffering */
    public function buffer(len : Int) : Void
    {
        var i : Int;
        var stream : SiOPMStream;
        
        if (_isIdling) {
            // idling process
            _nop(len);
        }
        else {
            // preserve _outPipe
            var monoOut : SLLint = _outPipe;
            
            // processing (update _outPipe inside)
            _funcProcess(len);
            
            // ring modulation / LPFilter
            if (_ringPipe != null)                 _applyRingModulation(monoOut, len);
            if (_filterOn)                 _applySVFilter(monoOut, len);

            // standard output
            if (_outputMode == OUTPUT_STANDARD && !_mute) {
                if (_hasEffectSend) {
                    for (i in 0...SiOPMModule.STREAM_SEND_SIZE){
                        if (_volumes[i] > 0) {
                            stream = _streams[i];
                            if (stream == null) stream = _chip.streamSlot[i];
                            if (stream != null) stream.write(monoOut, _bufferIndex, len, _volumes[i], _pan);
                        }
                    }
                }
                else {
                    stream = _streams[0];
                    if (stream == null) stream = _chip.outputStream;
                    stream.write(monoOut, _bufferIndex, len, _volumes[0], _pan);
                }
            }
        }

        // update buffer index
        _bufferIndex += len;
    }
    
    
    /** Buffering without processnig */
    public function nop(len : Int) : Void
    {
        _nop(len);
        _bufferIndex += len;
    }
    
    
    /** ring modulation */
    private function _applyRingModulation(pointer : SLLint, len : Int) : Void
    {
        var i : Int;
        var rp : SLLint = _ringPipe;
        for (i in 0...len){
            pointer.i *= Math.round(rp.i * _ringmodLevel);
            rp = rp.next;
            pointer = pointer.next;
        }
        _ringPipe = rp;
    }
    
    
    /** state variable filter */
    private function _applySVFilter(pointer : SLLint, len : Int, variables : Array<Float> = null) : Void
    {
        var i : Int;
        var imax : Int;
        var step : Int;
        var out : Int;
        var cut : Float;
        var fb : Float;
        
        // initialize
        if (variables == null)             variables = _filterVriables;
        out = _cutoff + _cutoff_offset;
        if (out < 0)             out = 0
        else if (out > 128)             out = 128;
        cut = _table.filter_cutoffTable[out];
        fb = _resonance;  // * _table.filter_feedbackTable[out];  
        
        // previous setting
        step = _prevStepRemain;
        
        while (len >= step){
            // processing
            for (i in 0...step){
                variables[2] = pointer.i - variables[0] - variables[1] * fb;
                variables[1] += variables[2] * cut;
                variables[0] += variables[1] * cut;
                pointer.i = Math.floor(variables[_filterType]);
                pointer = pointer.next;
            }
            len -= step;
            
            // change cutoff and shift state
            _cutoff += _filter_eg_cutoff_inc;
            out = _cutoff + _cutoff_offset;
            if (out < 0)                 out = 0
            else if (out > 128)                 out = 128;
            cut = _table.filter_cutoffTable[out];
            fb = _resonance;  // * _table.filter_feedbackTable[out];  
            if (_cutoff == _filter_eg_next) shiftSVFilterState(_filter_eg_state + 1);

            // next step
            step = _filter_eg_step;
        }

        // process remains
        for (i in 0...len){
            variables[2] = pointer.i - variables[0] - variables[1] * fb;
            variables[1] += variables[2] * cut;
            variables[0] += variables[1] * cut;
            pointer.i = Math.floor(variables[_filterType]);
            pointer = pointer.next;
        }

        // next setting
        _prevStepRemain = _filter_eg_step - len;
    }
    
    
    /** reset SVFilter */
    private function resetSVFilterState() : Void
    {
        _cutoff = _filter_eg_cutoff[EG_ATTACK];
    }
    
    
    /** shift SVFilter state */
    private function shiftSVFilterState(state : Int) : Void
    {
        /* TODO: Verify this is correct. Had to change a lot from the AS3. */
        function __shift() : Bool
        {
            if (_filter_eg_time[state] == 0)                 return false;
            _filter_eg_state = state;
            _filter_eg_step = _filter_eg_time[state];
            _filter_eg_next = _filter_eg_cutoff[state + 1];
            _filter_eg_cutoff_inc = ((_cutoff < _filter_eg_next)) ? 1 : -1;
            return (_cutoff != _filter_eg_next);
        };

        // This would be more elegant if haxe allows switch statements to fall through
        if ((state == EG_ATTACK) ||
            (state == EG_DECAY1) ||
            (state == EG_DECAY2) ||
            (state == EG_SUSTAIN))
        {
            if (state == EG_ATTACK) {
                if (__shift()) return;
                state++;
                // fall through
            }

            if (state == EG_DECAY1) {
                if (__shift()) return;
                state++;
                // fall through
            }

            if (state == EG_DECAY2) {
                if (__shift()) return;
                state++;
                // fall through
            }

            // catch all
            _filter_eg_state = EG_SUSTAIN;
            _filter_eg_step = INT_MAX_VALUE;
            _filter_eg_next = _cutoff + 1;
            _filter_eg_cutoff_inc = 0;
        }
        else if ((state == EG_RELEASE) ||
                 (state == EG_OFF))
        {
            if (state == EG_RELEASE) {
                if (__shift()) return;
                state++;
                // fall through
            }

            // catch all
            _filter_eg_state = EG_OFF;
            _filter_eg_step = INT_MAX_VALUE;
            _filter_eg_next = _cutoff + 1;
            _filter_eg_cutoff_inc = 0;
        }

        _prevStepRemain = _filter_eg_step;
    }
    
    
    
    /** No process (default functor of _funcProcess). */
    private function _nop(len : Int) : Void
    {
        var i : Int;
        var p : SLLint;
        
        // rotate output buffer
        if (_outputMode == OUTPUT_STANDARD) {
            _outPipe = _chip.getPipe(4, (_bufferIndex + len) & (_chip.bufferLength - 1));
        }
        else {
            p=_outPipe;
            for (i in 0...len){
                p = p.next;
            }
            _outPipe = p;
            _basePipe = ((_outputMode == OUTPUT_ADD)) ? p : _chip.zeroBuffer;
        }

        // rotate input buffer when connected by @i
        if (_inputMode == INPUT_PIPE) {
            p=_inPipe;
            for (i in 0...len){
                p = p.next;
            }
            _inPipe = p;
        }

        // rotate ring buffer
        if (_ringPipe != null) {
            p=_ringPipe;
            for (i in 0...len){
                p = p.next;
            }
            _ringPipe = p;
        }
    }
    
    
    
    
    // for channel manager operation [internal use]
    //--------------------------------------------------
    /** @private [internal] DLL of channels */
    @:allow(org.si.sion.module.channels)
    private var _isFree : Bool = true;
    /** @private [internal] DLL of channels */
    @:allow(org.si.sion.module.channels)
    private var _channelType : Int = -1;
    /** @private [internal] DLL of channels */
    @:allow(org.si.sion.module.channels)
    private var _next : SiOPMChannelBase = null;
    /** @private [internal] DLL of channels */
    @:allow(org.si.sion.module.channels)
    private var _prev : SiOPMChannelBase = null;
    
    /** channel type */
    private function get_channelType() : Int {
        return _channelType;
    }
}



