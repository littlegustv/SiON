//----------------------------------------------------------------------------------------------------
// SiOPM operator class
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.sion.module.channels;

import org.si.utils.SLLint;
import org.si.sion.module.*;


/** SiOPM operator class.
 *  This operator based on the OPM emulation of MAME, but its extended in below points,<br/>
 *  1) You can set the phase offest of pulse generator. <br/>
 *  2) You can select the wave form from some wave tables (see class SiOPMTable).<br/>
 *  3) You can set the key scale level.<br/>
 *  4) You can fix the pitch.<br/>
 *  5) You can set the ssgec in OPNA.<br/>
 */
class SiOPMOperator
{
    public var ar(get, set) : Int;
    public var dr(get, set) : Int;
    public var sr(get, set) : Int;
    public var rr(get, set) : Int;
    public var sl(get, set) : Int;
    public var tl(get, set) : Int;
    public var ks(get, set) : Int;
    public var mul(get, set) : Int;
    public var dt1(get, set) : Int;
    public var dt2(get, set) : Int;
    public var ame(get, set) : Bool;
    public var ams(get, set) : Int;
    public var ksl(get, set) : Int;
    public var ssgec(get, set) : Int;
    public var mute(get, set) : Bool;
    public var erst(get, set) : Bool;
    public var kc(get, set) : Int;
    public var kf(get, set) : Int;
    public var fnum(never, set) : Int;
    public var pitchFixed(get, never) : Bool;
    public var fixedPitchIndex(never, set) : Int;
    public var pitchIndex(get, set) : Int;
    public var detune(get, set) : Int;
    public var detune2(get, set) : Int;
    public var fmul(get, set) : Int;
    public var keyOnPhase(get, set) : Int;
    public var pgType(get, set) : Int;
    public var ptType(never, set) : Int;
    public var modLevel(get, set) : Int;

    // constants
    //--------------------------------------------------
    // State of envelop generator.
    public static inline var EG_ATTACK : Int = 0;
    public static inline var EG_DECAY : Int = 1;
    public static inline var EG_SUSTAIN : Int = 2;
    public static inline var EG_RELEASE : Int = 3;
    public static inline var EG_OFF : Int = 4;
    
    
    // waveFixedBits for PCM
    private static inline var PCM_waveFixedBits : Int = 11;
    
    
    
    
    // variables
    //--------------------------------------------------
    // [ IMPORTANT NOTE ]
    // The access levels of all variables are set as "internal".
    // The SiOPMChannelFM accesses these variables directly only from the wave processing functions to make it faster.
    // Never access these variables in other classes reason for the maintenances.
    //----------------------------------------------------------------------------------------------------
    /** @private table */
    @:allow(org.si.sion.module.channels)
    private var _table : SiOPMTable;
    /** @private chip */
    @:allow(org.si.sion.module.channels)
    private var _chip : SiOPMModule;
    
    
    // FM module parameters
    /** @private Attack rate [0,63] */
    @:allow(org.si.sion.module.channels)
    private var _ar : Int;
    /** @private Decay rate [0,63] */
    @:allow(org.si.sion.module.channels)
    private var _dr : Int;
    /** @private Sustain rate [0,63] */
    @:allow(org.si.sion.module.channels)
    private var _sr : Int;
    /** @private Release rate [0,63] */
    @:allow(org.si.sion.module.channels)
    private var _rr : Int;
    /** @private Sustain level [0,15] */
    @:allow(org.si.sion.module.channels)
    private var _sl : Int;
    /** @private Total level [0,127] */
    @:allow(org.si.sion.module.channels)
    private var _tl : Int;
    /** @private Key scaling rate = 5-ks [5,2] */
    @:allow(org.si.sion.module.channels)
    private var _ks : Int;
    /** @private Key scaling level [0,3] */
    @:allow(org.si.sion.module.channels)
    private var _ksl : Int;
    /** @private _multiple = (mul) ? (mul&lt;&lt;7) : 64; [64,128,256,384,512...] */
    @:allow(org.si.sion.module.channels)
    private var _multiple : Int;
    /** @private dt1 [0,7]. */
    @:allow(org.si.sion.module.channels)
    private var _dt1 : Int;
    /** @private dt2 [0,3]. This value is linked with _pitchIndexShift */
    @:allow(org.si.sion.module.channels)
    private var _dt2 : Int;
    /** @private Amp modulation shift [16,0] */
    @:allow(org.si.sion.module.channels)
    private var _ams : Int;
    /** @private Key code = oct&lt;&lt;4 + note [0,127] */
    @:allow(org.si.sion.module.channels)
    private var _kc : Int = 0;
    /** @private SSG type envelop control */
    @:allow(org.si.sion.module.channels)
    private var _ssg_type : Int;
    /** @private Mute [0/SiOPMTable.ENV_BOTTOM] */
    @:allow(org.si.sion.module.channels)
    private var _mute : Int;
    /** @priavet Envelop reset on attack */
    @:allow(org.si.sion.module.channels)
    private var _erst : Bool;
    
    
    // pulse generator
    /** @private pulse generator type */
    @:allow(org.si.sion.module.channels)
    private var _pgType : Int;
    /** @private pitch table type */
    @:allow(org.si.sion.module.channels)
    private var _ptType : Int;
    /** @private wave table */
    @:allow(org.si.sion.module.channels)
    private var _waveTable : Array<Int>;
    /** @private phase shift */
    @:allow(org.si.sion.module.channels)
    private var _waveFixedBits : Int;
    /** @private phase step shift */
    @:allow(org.si.sion.module.channels)
    private var _wavePhaseStepShift : Int;
    /** @private pitch table */
    @:allow(org.si.sion.module.channels)
    private var _pitchTable : Array<Int>;
    /** @private pitch table index filter */
    @:allow(org.si.sion.module.channels)
    private var _pitchTableFilter : Int;
    /** @private phase */
    @:allow(org.si.sion.module.channels)
    private var _phase : Int;
    /** @private phase step */
    @:allow(org.si.sion.module.channels)
    private var _phase_step : Int;
    /** @private keyOn phase. -1 sets no phase reset. */
    @:allow(org.si.sion.module.channels)
    private var _keyon_phase : Int;
    /** @private pitch fixed */
    @:allow(org.si.sion.module.channels)
    private var _pitchFixed : Bool;
    /** @private dt1 table */
    @:allow(org.si.sion.module.channels)
    private var _dt1Table : Array<Int>;
    
    
    /** @private pitch index = note * 64 + key fraction */
    @:allow(org.si.sion.module.channels)
    private var _pitchIndex : Int = 0;
    /** @private pitch index shift. This value is linked with dt2 and detune. */
    @:allow(org.si.sion.module.channels)
    private var _pitchIndexShift : Int = 0;
    /** @private pitch index shift by pitch modulation. This value is linked with dt2. */
    @:allow(org.si.sion.module.channels)
    private var _pitchIndexShift2 : Int = 0;
    /** @private frequency modulation left-shift. 15 for FM, fb+6 for feedback. */
    @:allow(org.si.sion.module.channels)
    private var _fmShift : Int;
    
    
    // envelop generator
    /** @private State [EG_ATTACK, EG_DECAY, EG_SUSTAIN, EG_RELEASE, EG_OFF] */
    @:allow(org.si.sion.module.channels)
    private var _eg_state : Int;
    /** @private Envelop generator updating timer, initialized (2047 * 3) &lt;&lt; CLOCK_RATIO_BITS. */
    @:allow(org.si.sion.module.channels)
    private var _eg_timer : Int;
    /** @private Timer stepping by samples */
    @:allow(org.si.sion.module.channels)
    private var _eg_timer_step : Int;
    /** @private Counter rounded on 8. */
    @:allow(org.si.sion.module.channels)
    private var _eg_counter : Int;
    /** @private Internal sustain level [0,SiOPMTable.ENV_BOTTOM] */
    @:allow(org.si.sion.module.channels)
    private var _eg_sustain_level : Int;
    /** @private Internal total level [0,1024] = ((tl + f(kc, ksl)) &lt;&lt; 3) + _eg_tl_offset + 192. */
    @:allow(org.si.sion.module.channels)
    private var _eg_total_level : Int;
    /** @private Internal total level offset by volume [-192,832]*/
    @:allow(org.si.sion.module.channels)
    private var _eg_tl_offset : Int = 0;
    /** @private Internal key scaling rate = _kc >> _ks [0,32] */
    @:allow(org.si.sion.module.channels)
    private var _eg_key_scale_rate : Int;
    /** @private Internal key scaling level right shift = _ksl[0,1,2,3]->[8,2,1,0] */
    @:allow(org.si.sion.module.channels)
    private var _eg_key_scale_level_rshift : Int;
    /** @private Envelop generator level [0,1024] */
    @:allow(org.si.sion.module.channels)
    private var _eg_level : Int = 0;
    /** @private Envelop generator output [0,1024&lt;&lt;3] */
    @:allow(org.si.sion.module.channels)
    private var _eg_out : Int;
    /** @private SSG envelop control ar switch */
    @:allow(org.si.sion.module.channels)
    private var _eg_ssgec_ar : Int;
    /** @private SSG envelop control state */
    @:allow(org.si.sion.module.channels)
    private var _eg_ssgec_state : Int;
    
    /** @private Increment table picked up from _eg_incTables or _eg_incTablesAtt. */
    @:allow(org.si.sion.module.channels)
    private var _eg_incTable : Array<Int>;
    /** @private The level to shift the state to next. */
    @:allow(org.si.sion.module.channels)
    private var _eg_stateShiftLevel : Int;
    /** @private Next status list */
    @:allow(org.si.sion.module.channels)
    private var _eg_nextState : Array<Int>;
    /** @private _eg_level converter */
    @:allow(org.si.sion.module.channels)
    private var _eg_levelTable : Array<Int>;
    // Next status table
    private static var _table_nextState : Array<Dynamic> = [
        //            EG_ATTACK,  EG_DECAY,   EG_SUSTAIN, EG_RELEASE, EG_OFF
        [EG_DECAY, EG_SUSTAIN, EG_OFF, EG_OFF, EG_OFF],   // normal  
        [EG_DECAY, EG_SUSTAIN, EG_ATTACK, EG_OFF, EG_OFF]  // ssgev
        ];
    
    
    // pipes
    /** @private flag that is final carrior. */
    @:allow(org.si.sion.module.channels)
    private var _final : Bool;
    /** @private modulator output */
    @:allow(org.si.sion.module.channels)
    private var _inPipe : SLLint;
    /** @private base */
    @:allow(org.si.sion.module.channels)
    private var _basePipe : SLLint;
    /** @private output */
    @:allow(org.si.sion.module.channels)
    private var _outPipe : SLLint;
    /** @private feed back */
    @:allow(org.si.sion.module.channels)
    private var _feedPipe : SLLint;
    
    // for PCM wave
    /** @private channel count */
    @:allow(org.si.sion.module.channels)
    private var _pcm_channels : Int;
    /** @private start point */
    @:allow(org.si.sion.module.channels)
    private var _pcm_startPoint : Int;
    /** @private end point */
    @:allow(org.si.sion.module.channels)
    private var _pcm_endPoint : Int;
    /** @private loop point */
    @:allow(org.si.sion.module.channels)
    private var _pcm_loopPoint : Int;
    
    
    
    // properties (fm parameters)
    //--------------------------------------------------
    /** Attack rate [0,63] */
    private function set_ar(i : Int) : Int{
        _ar = i & 63;
        _eg_ssgec_ar = ((_ssg_type == 8 || _ssg_type == 12)) ? (((_ar >= 56)) ? 1 : 0) : (((_ar >= 60)) ? 1 : 0);
        return i;
    }
    /** Decay rate [0,63] */
    private function set_dr(i : Int) : Int{_dr = i & 63;
        return i;
    }
    /** Sustain rate [0,63] */
    private function set_sr(i : Int) : Int{_sr = i & 63;
        return i;
    }
    /** Release rate [0,63] */
    private function set_rr(i : Int) : Int{_rr = i & 63;
        return i;
    }
    /** Sustain level [0,15] */
    private function set_sl(i : Int) : Int{
        _sl = i & 15;
        _eg_sustain_level = _table.eg_slTable[i];
        return i;
    }
    /** Total level [0,127] */
    private function set_tl(i : Int) : Int {
        _tl = ((i < 0)) ? 0 : ((i > 127)) ? 127 : i;
        _updateTotalLevel();
        return i;
    }
    /** Key scaling rate [0,3] */
    private function set_ks(i : Int) : Int{
        _ks = 5 - (i & 3);
        _eg_key_scale_rate = _kc >> _ks;
        return i;
    }
    /** multiple [0,15] */
    private function set_mul(m : Int) : Int{
        m &= 15;
        _multiple = ((m != 0)) ? (m << 7) : 64;
        _updatePitch();
        return m;
    }
    /** dt1 [0-7] */
    private function set_dt1(d : Int) : Int{
        _dt1 = d & 7;
        _dt1Table = _table.dt1Table[_dt1];
        _updatePitch();
        return d;
    }
    /** dt2 [0-3] */
    private function set_dt2(d : Int) : Int{
        _dt2 = d & 3;
        _pitchIndexShift = _table.dt2Table[_dt2];
        _updatePitch();
        return d;
    }
    /** amplitude modulation enable [t/f] */
    private function set_ame(b : Bool) : Bool{
        _ams = ((b)) ? 2 : 16;
        return b;
    }
    /** amplitude modulation shift [t/f] */
    private function set_ams(s : Int) : Int{
        _ams = ((s != 0)) ? (3 - s) : 16;
        return s;
    }
    /** Key scaling level [0,3] */
    private function set_ksl(i : Int) : Int{
        _ksl = i;
        // [0,1,2,3]->[8,4,3,2]
        _eg_key_scale_level_rshift = ((i == 0)) ? 8 : (5 - i);
        _updateTotalLevel();
        return i;
    }
    /** SSG type envelop control */
    private function set_ssgec(i : Int) : Int{
        if (i > 7) {
            _eg_nextState = _table_nextState[1];
            _ssg_type = i;
            if (_ssg_type > 17)                 _ssg_type = 9;
        }
        else {
            _eg_nextState = _table_nextState[0];
            _ssg_type = 0;
        }
        return i;
    }
    /** Mute */
    private function set_mute(b : Bool) : Bool{
        _mute = ((b)) ? SiOPMTable.ENV_BOTTOM : 0;
        _updateTotalLevel();
        return b;
    }
    /** Envelop reset on attack */
    private function set_erst(b : Bool) : Bool{
        _erst = b;
        return b;
    }
    
    
    private function get_ar() : Int{return _ar;
    }
    private function get_dr() : Int{return _dr;
    }
    private function get_sr() : Int{return _sr;
    }
    private function get_rr() : Int{return _rr;
    }
    private function get_sl() : Int{return _sl;
    }
    private function get_tl() : Int{return _tl;
    }
    private function get_ks() : Int{return 5 - _ks;
    }
    private function get_mul() : Int{return (_multiple >> 7);
    }
    private function get_dt1() : Int{return _dt1;
    }
    private function get_dt2() : Int{return _dt2;
    }
    private function get_ame() : Bool{return (_ams != 16);
    }
    private function get_ams() : Int{return ((_ams == 16)) ? 0 : (3 - _ams);
    }
    private function get_ksl() : Int{return _ksl;
    }
    private function get_ssgec() : Int{return _ssg_type;
    }
    private function get_mute() : Bool{return (_mute != 0);
    }
    private function get_erst() : Bool{return _erst;
    }
    
    
    // properties (other fm parameters)
    //--------------------------------------------------
    /** Key code [0,127] */
    private function set_kc(i : Int) : Int{
        if (_pitchFixed) return 0;
        _updateKC(i & 127);
        _pitchIndex = ((_kc - (_kc >> 2)) << 6) | (_pitchIndex & 63);
        _updatePitch();
        return i;
    }
    /** key fraction [0-63] */
    private function set_kf(f : Int) : Int{
        _pitchIndex = (_pitchIndex & 0xffc0) | (f & 63);
        _updatePitch();
        return f;
    }
    /** F-Number for OPNA. This property resets kf,dt2 and detune. */
    private function set_fnum(f : Int) : Int{
        // dishonest implement.
        _updateKC((f >> 7) & 127);
        _dt2 = 0;
        _pitchIndex = 0;
        _pitchIndexShift = 0;
        _updatePhaseStep((f & 2047) << ((f >> 11) & 7));
        return f;
    }
    
    // Get status, but all of them cannot be read.
    private function get_kc() : Int{return _kc;
    }
    private function get_kf() : Int{return (_pitchIndex & 63);
    }
    private function get_pitchFixed() : Bool{return _pitchFixed;
    }
    
    
    // properties (pTSS)
    //--------------------------------------------------
    /** Fixed pitch index. 0 means fixed off. */
    private function set_fixedPitchIndex(i : Int) : Int{
        if (i > 0) {
            _pitchIndex = i;
            _updateKC(_table.nnToKC[(i >> 6) & 127]);
            _updatePitch();
            _pitchFixed = true;
        }
        else {
            _pitchFixed = false;
        }
        return i;
    }
    /** pitchIndex = (note &lt;&lt; 6) | (kf &amp; 63) [0,8191] */
    private function set_pitchIndex(i : Int) : Int
    {
        if (_pitchFixed) return 0;
        _pitchIndex = i;
        _updateKC(_table.nnToKC[(i >> 6) & 127]);
        _updatePitch();
        return i;
    }
    /** Detune for pTSS. 1 halftone divides into 64 steps. This property resets dt2. */
    private function set_detune(d : Int) : Int{
        _dt2 = 0;
        _pitchIndexShift = d;
        _updatePitch();
        return d;
    }
    /** Detune for pitch modulation. This is independent value. */
    private function set_detune2(d : Int) : Int{
        _pitchIndexShift2 = d;
        _updatePitch();
        return d;
    }
    /** Fine multiple for pTSS. 128=x1. */
    private function set_fmul(m : Int) : Int{
        _multiple = m;
        _updatePitch();
        return m;
    }
    /** Phase at keyOn [-1-255]. similar with pTSS. The value of 255 sets no phase reset, -1 sets randamize. */
    private function set_keyOnPhase(p : Int) : Int{
        if (p == 255)             _keyon_phase = -2
        else if (p == -1)             _keyon_phase = -1
        else _keyon_phase = (p & 255) << (SiOPMTable.PHASE_BITS - 8);
        return p;
    }
    /** Pulse generator type. */
    private function set_pgType(n : Int) : Int
    {
        _pgType = n & SiOPMTable.PG_FILTER;
        var waveTable : SiOPMWaveTable = _table.getWaveTable(_pgType);
        _waveTable = waveTable.wavelet;
        _waveFixedBits = waveTable.fixedBits;
        return n;
    }
    /** Pitch table type. */
    private function set_ptType(n : Int) : Int
    {
        _ptType = n;
        _wavePhaseStepShift = (SiOPMTable.PHASE_BITS - _waveFixedBits) & _table.phaseStepShiftFilter[n];
        _pitchTable = _table.pitchTable[n];
        _pitchTableFilter = _pitchTable.length - 1;
        return n;
    }
    /** Frequency modulation level. 15 is standard modulation. */
    private function set_modLevel(m : Int) : Int{
        _fmShift = ((m != 0)) ? (m + 10) : 0;
        return m;
    }
    
    
    private function get_pitchIndex() : Int{return _pitchIndex;
    }
    private function get_detune() : Int{return _pitchIndexShift;
    }
    private function get_detune2() : Int{return _pitchIndexShift2;
    }
    private function get_fmul() : Int{return _multiple;
    }
    private function get_keyOnPhase() : Int{return ((_keyon_phase >= 0)) ? (_keyon_phase >> (SiOPMTable.PHASE_BITS - 8)) : ((_keyon_phase == -1)) ? -1 : 255;
    }
    private function get_pgType() : Int{return _pgType;
    }
    private function get_modLevel() : Int{return ((_fmShift > 10)) ? (_fmShift - 10) : 0;
    }
    
    
    /** @private [internal] tl offset [832,-192]. controlled as expression and velocity. */
    @:allow(org.si.sion.module.channels)
    private function _tlOffset(i : Int) : Void{
        _eg_tl_offset = i;
        _updateTotalLevel();
    }
    
    
    public function toString() : String
    {
        var str : String = "SiOPMOperator : ";
        str += Std.string(pgType) + "/";
        str += Std.string(ar) + "/";
        str += Std.string(dr) + "/";
        str += Std.string(sr) + "/";
        str += Std.string(rr) + "/";
        str += Std.string(sl) + "/";
        str += Std.string(tl) + "/";
        str += Std.string(ks) + "/";
        str += Std.string(ksl) + "/";
        str += Std.string(fmul) + "/";
        str += Std.string(dt1) + "/";
        str += Std.string(detune) + "/";
        str += Std.string(ams) + "/";
        str += Std.string(ssgec) + "/";
        str += Std.string(keyOnPhase) + "/";
        str += Std.string(pitchFixed);
        return str;
    }
    
    
    
    
    // constructor
    //--------------------------------------------------
    /** constructor */
    public function new(chip : SiOPMModule)
    {
        // trace('              ########## SiOPMOperator($chip) ##########');
        _table = SiOPMTable.instance;
        _chip = chip;
        _feedPipe = SLLint.allocRing(1);
        _eg_incTable = _table.eg_incTables[17];
        _eg_levelTable = _table.eg_levelTables[0];
        _eg_nextState = _table_nextState[0];
    }
    
    
    
    
    // operations
    //--------------------------------------------------
    /** Initialize. */
    public function initialize() : Void
    {
        // reset operator connections
        _final = true;
        _inPipe = _chip.zeroBuffer;
        _basePipe = _chip.zeroBuffer;
        _feedPipe.i = 0;

        // reset all parameters
        setSiOPMOperatorParam(_chip.initOperatorParam);

        // reset some other parameters
        _eg_tl_offset = 0;  // The _eg_tl_offset is controled by velocity and expression.  
        _pitchIndexShift2 = 0;  // The _pitchIndexShift2 is controled by pitch modulation.  
        _pcm_channels = 0;
        _pcm_startPoint = 0;
        _pcm_endPoint = 0;
        _pcm_loopPoint = -1;

        // reset pg and eg status
        reset();
    }
    
    
    /** Reset. */
    public function reset() : Void
    {
        _eg_shiftState(EG_OFF);
        _eg_out = (_eg_levelTable[_eg_level] + _eg_total_level) << 3;
        _eg_timer = SiOPMTable.ENV_TIMER_INITIAL;
        _eg_counter = 0;
        _eg_ssgec_state = 0;
        _phase = 0;
    }
    
    
    /** Set paramaters by SiOPMOperatorParam */
    public function setSiOPMOperatorParam(param : SiOPMOperatorParam) : Void
    {
        pgType = param.pgType;
        ptType = param.ptType;
        
        if (param.phase == 255) _keyon_phase = -2
        else if (param.phase == -1) _keyon_phase = -1
        else _keyon_phase = (param.phase & 255) << (SiOPMTable.PHASE_BITS - 8);

        _ar = param.ar & 63;
        _dr = param.dr & 63;
        _sr = param.sr & 63;
        _rr = param.rr & 63;
        _ks = 5 - (param.ksr & 3);
        _ksl = param.ksl & 3;
        _ams = ((param.ams != 0)) ? (3 - param.ams) : 16;
        _multiple = param.fmul;
        _fmShift = (param.modLevel & 7) + 10;
        _dt1 = param.dt1 & 7;
        _dt1Table = _table.dt1Table[_dt1];
        _pitchIndexShift = param.detune;
        ssgec = param.ssgec;
        _mute = ((param.mute)) ? SiOPMTable.ENV_BOTTOM : 0;
        _erst = param.erst;

        // fixed pitch
        if (param.fixedPitch == 0) {
            //_pitchIndex = 3840;
            //_updateKC(_table.nnToKC[(_pitchIndex>>6)&127]);
            _pitchFixed = false;
        }
        else {
            _pitchIndex = param.fixedPitch;
            _updateKC(_table.nnToKC[(_pitchIndex >> 6) & 127]);
            _pitchFixed = true;
        }

        // key scale level
        _eg_key_scale_level_rshift = (_ksl == 0) ? 8 : (5 - _ksl);
        // ar for ssgec
        _eg_ssgec_ar = ((_ssg_type == 8 || _ssg_type == 12)) ? (((_ar >= 56)) ? 1 : 0) : (((_ar >= 60)) ? 1 : 0);
        // sl,tl requires some special calculation
        sl = param.sl & 15;
        tl = param.tl;

        _updatePitch();
    }
    
    
    /** Get paramaters by SiOPMOperatorParam */
    public function getSiOPMOperatorParam(param : SiOPMOperatorParam) : Void
    {
        param.pgType = _pgType;
        param.ptType = _ptType;
        
        param.ar = _ar;
        param.dr = _dr;
        param.sr = _sr;
        param.rr = _rr;
        param.sl = sl;
        param.tl = tl;
        param.ksr = ks;
        param.ksl = ksl;
        param.fmul = fmul;
        param.dt1 = _dt1;
        param.detune = detune;
        param.ams = ams;
        param.ssgec = ssgec;
        param.phase = keyOnPhase;
        param.modLevel = ((_fmShift > 10)) ? (_fmShift - 10) : 0;
        param.erst = _erst;
    }
    
    
    /** Set Wave table data. */
    public function setWaveTable(waveTable : SiOPMWaveTable) : Void
    {
        _pgType = SiOPMTable.PG_USER_CUSTOM;  // -1  
        _waveTable = waveTable.wavelet;
        _waveFixedBits = waveTable.fixedBits;
        ptType = waveTable.defaultPTType;
    }
    
    
    /** Set PCM data. */
    public function setPCMData(pcmData : SiOPMWavePCMData) : Void
    {
        if (pcmData != null && pcmData.wavelet != null) {
            _pgType = SiOPMTable.PG_USER_PCM;  // -2  
            _waveTable = pcmData.wavelet;
            _waveFixedBits = PCM_waveFixedBits;
            _pcm_channels = pcmData.channelCount;
            _pcm_startPoint = pcmData.startPoint;
            _pcm_endPoint = pcmData.endPoint;
            _pcm_loopPoint = pcmData.loopPoint;
            _keyon_phase = _pcm_startPoint << PCM_waveFixedBits;
            ptType = SiOPMTable.PT_PCM;
        }
        else {
            // quick initialization for SiOPMChannelPCM
            _pcm_endPoint = _pcm_loopPoint = 0;
            _pcm_loopPoint = -1;
        }
    }
    
    
    /** Note on. */
    public function noteOn() : Void
    {
        if (_keyon_phase >= 0)             _phase = _keyon_phase
        else if (_keyon_phase == -1)             _phase = Math.floor(Math.random() * SiOPMTable.PHASE_MAX);
        _eg_ssgec_state = -1;
        _eg_shiftState(EG_ATTACK);
        _eg_out = (_eg_levelTable[_eg_level] + _eg_total_level) << 3;
    }
    
    
    /** Note off. */
    public function noteOff() : Void
    {
        _eg_shiftState(EG_RELEASE);
        _eg_out = (_eg_levelTable[_eg_level] + _eg_total_level) << 3;
    }
    
    
    /** @private [internal] Set pipes. */
    @:allow(org.si.sion.module.channels)
    private function _setPipes(outPipe : SLLint, modPipe : SLLint = null, finalOsc : Bool = false) : Void
    {
        _final = finalOsc;
        _basePipe = ((outPipe == modPipe)) ? _chip.zeroBuffer : outPipe;
        _outPipe = outPipe;
        _inPipe = modPipe;
        if (_inPipe == null) _inPipe = _chip.zeroBuffer;
        _fmShift = 15;
    }
    
    
    
    
    // internal operations
    //--------------------------------------------------
    /** @private Update envelop generator. This code is only for testing. */
    @:allow(org.si.sion.module.channels)
    private function eg_update() : Void
    {
        _eg_timer -= _eg_timer_step;
        if (_eg_timer < 0) {
            if (_eg_state == EG_ATTACK) {
                if (_eg_incTable[_eg_counter] > 0) {
                    _eg_level -= 1 + (_eg_level >> _eg_incTable[_eg_counter]);
                    if (_eg_level <= 0)                         _eg_shiftState(_eg_nextState[_eg_state]);
                }
            }
            else {
                _eg_level += _eg_incTable[_eg_counter];
                if (_eg_level >= _eg_stateShiftLevel)                     _eg_shiftState(_eg_nextState[_eg_state]);
            }
            _eg_out = (_eg_levelTable[_eg_level] + _eg_total_level) << 3;
            _eg_counter = (_eg_counter + 1) & 7;
            _eg_timer += SiOPMTable.ENV_TIMER_INITIAL;
        }
    }
    
    
    /** @private Update pulse generator. This code is only for testing. */
    @:allow(org.si.sion.module.channels)
    private function pg_update() : Void
    {
        _phase += _phase_step;
        var p : Int = ((_phase + (_inPipe.i << _fmShift)) & SiOPMTable.PHASE_FILTER) >> _waveFixedBits;
        var l : Int = _waveTable[p];
        l += _eg_out;  // + (channel._am_out<<2>>_ams);  
        _feedPipe.i = _table.logTable[l];
        _outPipe.i = _feedPipe.i + _basePipe.i;
    }
    
    
    /** @private Shift envelop generator state. */
    @:allow(org.si.sion.module.channels)
    private function _eg_shiftState(state : Int) : Void
    {
        var r : Int;

        function OFF() : Void {
            // catch all
            _eg_state = EG_OFF;
            _eg_level = SiOPMTable.ENV_BOTTOM;
            _eg_stateShiftLevel = SiOPMTable.ENV_BOTTOM + 1;
            _eg_incTable = _table.eg_incTables[17];  // 17 = all zero
            _eg_timer_step = _table.eg_timerSteps[96];  // 96 = all zero
            _eg_levelTable = _table.eg_levelTables[0];
        }

        function RELEASE() : Void {
            if (_eg_level < SiOPMTable.ENV_BOTTOM) {
                _eg_state = EG_RELEASE;
                _eg_stateShiftLevel = SiOPMTable.ENV_BOTTOM;
                r = _rr + _eg_key_scale_rate;
                _eg_incTable = _table.eg_incTables[_table.eg_tableSelector[r]];
                _eg_timer_step = _table.eg_timerSteps[r];
                _eg_levelTable = _table.eg_levelTables[((_ssg_type != 0)) ? 1 : 0];
                return;
            }

            // fail through
            OFF();
        }

        function SUSTAIN() : Void {
            _eg_state = EG_SUSTAIN;
            if (_ssg_type != 0) {
                _eg_level = _eg_sustain_level >> 2;
                _eg_stateShiftLevel = SiOPMTable.ENV_BOTTOM_SSGEC;
                _eg_levelTable = _table.eg_levelTables[_table.eg_ssgTableIndex[_ssg_type - 8][_eg_ssgec_ar][_eg_ssgec_state]];
            }
            else {
                _eg_level = _eg_sustain_level;
                _eg_stateShiftLevel = SiOPMTable.ENV_BOTTOM;
                _eg_levelTable = _table.eg_levelTables[0];
            }
            r = ((_sr != 0)) ? (_sr + _eg_key_scale_rate) : 96;
            _eg_incTable = _table.eg_incTables[_table.eg_tableSelector[r]];
            _eg_timer_step = _table.eg_timerSteps[r];
        }

        function DECAY() : Void {
            if (_eg_sustain_level != 0) {
                _eg_state = EG_DECAY;
                if (_ssg_type != 0) {
                    _eg_level = 0;
                    _eg_stateShiftLevel = _eg_sustain_level >> 2;
                    if (_eg_stateShiftLevel > SiOPMTable.ENV_BOTTOM_SSGEC) _eg_stateShiftLevel = SiOPMTable.ENV_BOTTOM_SSGEC;
                    _eg_levelTable = _table.eg_levelTables[_table.eg_ssgTableIndex[_ssg_type - 8][_eg_ssgec_ar][_eg_ssgec_state]];
                }
                else {
                    _eg_level = 0;
                    _eg_stateShiftLevel = _eg_sustain_level;
                    _eg_levelTable = _table.eg_levelTables[0];
                }
                r = ((_dr != 0)) ? (_dr + _eg_key_scale_rate) : 96;
                _eg_incTable = _table.eg_incTables[_table.eg_tableSelector[r]];
                _eg_timer_step = _table.eg_timerSteps[r];
                return;
            }

            // fail through
            SUSTAIN();
        }

        function ATTACK() : Void {
            // update ssgec_state
            if (++_eg_ssgec_state == 3) _eg_ssgec_state = 1;
            if (_ar + _eg_key_scale_rate < 62) {
                if (_erst) _eg_level = SiOPMTable.ENV_BOTTOM;
                _eg_state = EG_ATTACK;
                r = (_ar != 0) ? (_ar + _eg_key_scale_rate) : 96;
                _eg_incTable = _table.eg_incTablesAtt[_table.eg_tableSelector[r]];
                _eg_timer_step = _table.eg_timerSteps[r];
                _eg_levelTable = _table.eg_levelTables[0];
                return;
            }

            // fail through
            DECAY();
        }


        switch (state)
        {
            case EG_ATTACK:
                ATTACK();

            case EG_DECAY:
                DECAY();

            case EG_SUSTAIN:
                SUSTAIN();

            case EG_RELEASE:
                RELEASE();

            case EG_OFF:
                OFF();

            default:
                // catch all
                _eg_state = EG_OFF;
                _eg_level = SiOPMTable.ENV_BOTTOM;
                _eg_stateShiftLevel = SiOPMTable.ENV_BOTTOM + 1;
                _eg_incTable = _table.eg_incTables[17];  // 17 = all zero  
                _eg_timer_step = _table.eg_timerSteps[96];  // 96 = all zero  
                _eg_levelTable = _table.eg_levelTables[0];
        }
    }
    
    
    // Internal update key code
    private function _updateKC(i : Int) : Void
    {
        // kc
        _kc = i;
        // ksr
        _eg_key_scale_rate = _kc >> _ks;
        // ksl
        _updateTotalLevel();
    }
    
    
    // Internal update phase step
    private function _updatePitch() : Void
    {
        var n : Int = (_pitchIndex + _pitchIndexShift + _pitchIndexShift2) & _pitchTableFilter;
        _updatePhaseStep(_pitchTable[n] >> _wavePhaseStepShift);
    }
    
    
    // Internal update phase step
    private function _updatePhaseStep(ps : Int) : Void
    {
        _phase_step = ps;
        _phase_step += _dt1Table[_kc];
        _phase_step *= _multiple;
        _phase_step >>= (7 - _table.sampleRatePitchShift);
    }
    
    
    // Internal update total level
    private function _updateTotalLevel() : Void
    {
        _eg_total_level = ((_tl + (_kc >> _eg_key_scale_level_rshift)) << SiOPMTable.ENV_LSHIFT) + _eg_tl_offset + _mute;
        if (_eg_total_level > SiOPMTable.ENV_BOTTOM) _eg_total_level = SiOPMTable.ENV_BOTTOM;
        _eg_total_level -= SiOPMTable.ENV_TOP;  // table index +192.
        _eg_out = (_eg_levelTable[_eg_level] + _eg_total_level) << 3;
    }
}


