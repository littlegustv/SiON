//----------------------------------------------------------------------------------------------------
// class for SiOPM tables
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.sion.module;

import openfl.errors.Error;
import org.si.sion.sequencer.SiMMLVoice;
import org.si.sion.module.SiOPMWavePCMTable;
import org.si.sion.module.SiOPMWaveSamplerData;
import org.si.sion.module.SiOPMWaveSamplerTable;
import org.si.sion.module.SiOPMWaveTable;

import openfl.media.Sound;
import org.si.utils.SLLint;
import org.si.sion.sequencer.SiMMLVoice;



/** SiOPM table */
class SiOPMTable
{
    public static var instance(get, never) : SiOPMTable;

    // constants
    //--------------------------------------------------
    public static inline var ENV_BITS : Int = 10;  // Envelop output bit size  
    public static inline var ENV_TIMER_BITS : Int = 24;  // Envelop timer resolution bit size  
    public static inline var SAMPLING_TABLE_BITS : Int = 10;  // sine wave table entries = 2 ^ SAMPLING_TABLE_BITS = 1024  
    public static inline var HALF_TONE_BITS : Int = 6;  // half tone resolution    = 2 ^ HALF_TONE_BITS      = 64  
    public static inline var NOTE_BITS : Int = 7;  // max note value          = 2 ^ NOTE_BITS           = 128  
    public static inline var NOISE_TABLE_BITS : Int = 15;  // 32k noise  
    public static inline var LOG_TABLE_RESOLUTION : Int = 256;  // log table resolution    = LOG_TABLE_RESOLUTION for every 1/2 scaling.  
    public static inline var LOG_VOLUME_BITS : Int = 13;  // _logTable[0] = 2^13 at maximum  
    public static inline var LOG_TABLE_MAX_BITS : Int = 16;  // _logTable entries  
    public static inline var FIXED_BITS : Int = 16;  // internal fixed point 16.16  
    public static inline var PCM_BITS : Int = 20;  // maximum PCM sample length = 2 ^ PCM_BITS = 1048576  
    public static inline var LFO_FIXED_BITS : Int = 20;  // fixed point for lfo timer  
    public static inline var CLOCK_RATIO_BITS : Int = 10;  // bits for clock/64/[sampling rate]  
    public static inline var NOISE_WAVE_OUTPUT : Float = 1;  // -2044 < [noise amplitude] < 2040 -> NOISE_WAVE_OUTPUT=0.25  
    public static inline var SQUARE_WAVE_OUTPUT : Float = 1;  //  
    public static inline var OUTPUT_MAX : Float = 0.5;  // maximum output  
    
    public static var ENV_LSHIFT : Int = ENV_BITS - 7;  // Shift number from input tl [0,127] to internal value [0,ENV_BOTTOM].  
    public static var ENV_TIMER_INITIAL : Int = (2047 * 3) << CLOCK_RATIO_BITS;  // envelop timer initial value  
    public static var LFO_TIMER_INITIAL : Int = 1 << SiOPMTable.LFO_FIXED_BITS;  // lfo timer initial value  
    public static var PHASE_BITS : Int = SAMPLING_TABLE_BITS + FIXED_BITS;  // internal phase is expressed by 10.16 fixed.  
    public static var PHASE_MAX : Int = 1 << PHASE_BITS;
    public static var PHASE_FILTER : Int = PHASE_MAX - 1;
    public static var PHASE_SIGN_RSHIFT : Int = PHASE_BITS - 1;
    public static var SAMPLING_TABLE_SIZE : Int = 1 << SAMPLING_TABLE_BITS;
    public static var NOISE_TABLE_SIZE : Int = 1 << NOISE_TABLE_BITS;
    public static var PITCH_TABLE_SIZE : Int = 1 << (HALF_TONE_BITS + NOTE_BITS);
    public static var NOTE_TABLE_SIZE : Int = 1 << NOTE_BITS;
    public static var HALF_TONE_RESOLUTION : Int = 1 << HALF_TONE_BITS;
    public static var LOG_TABLE_SIZE : Int = LOG_TABLE_MAX_BITS * LOG_TABLE_RESOLUTION * 2;  // *2 posi&nega  
    public static inline var LFO_TABLE_SIZE : Int = 256;  // FIXED VALUE !!  
    public static inline var KEY_CODE_TABLE_SIZE : Int = 128;  // FIXED VALUE !!  
    public static var LOG_TABLE_BOTTOM : Int = LOG_VOLUME_BITS * LOG_TABLE_RESOLUTION * 2;  // bottom value of log table = 6656  
    public static var ENV_BOTTOM : Int = (LOG_VOLUME_BITS * LOG_TABLE_RESOLUTION) >> 2;  // minimum gain of envelop = 832  
    public static var ENV_TOP : Int = ENV_BOTTOM - (1 << ENV_BITS);  // maximum gain of envelop = -192  
    public static var ENV_BOTTOM_SSGEC : Int = 1 << (ENV_BITS - 3);  // minimum gain of ssgec envelop = 128  
    
    // pitch table type
    public static inline var PT_OPM : Int = 0;
    public static inline var PT_PCM : Int = 1;
    public static inline var PT_PSG : Int = 2;
    public static inline var PT_OPM_NOISE : Int = 3;
    public static inline var PT_PSG_NOISE : Int = 4;
    public static inline var PT_APU_NOISE : Int = 5;
    public static inline var PT_GB_NOISE : Int = 6;
    //        static public const PT_APU_DPCM:int = 7;
    public static inline var PT_MAX : Int = 7;
    
    // pulse generator type (0-511)
    public static inline var PG_SINE : Int = 0;  // sine wave  
    public static inline var PG_SAW_UP : Int = 1;  // upward saw wave  
    public static inline var PG_SAW_DOWN : Int = 2;  // downward saw wave  
    public static inline var PG_TRIANGLE_FC : Int = 3;  // triangle wave quantized by 4bit  
    public static inline var PG_TRIANGLE : Int = 4;  // triangle wave  
    public static inline var PG_SQUARE : Int = 5;  // square wave  
    public static inline var PG_NOISE : Int = 6;  // 32k white noise  
    public static inline var PG_KNMBSMM : Int = 7;  // knmbsmm wave  
    public static inline var PG_SYNC_LOW : Int = 8;  // pseudo sync (low freq.)  
    public static inline var PG_SYNC_HIGH : Int = 9;  // pseudo sync (high freq.)  
    public static inline var PG_OFFSET : Int = 10;  // offset  
    public static inline var PG_SAW_VC6 : Int = 11;  // vc6 saw (32 samples saw)  
    // ( 12-  15) reserved
    // ( 11-  15) reserved
    public static inline var PG_NOISE_WHITE : Int = 16;  // 16k white noise  
    public static inline var PG_NOISE_PULSE : Int = 17;  // 16k pulse noise  
    public static inline var PG_NOISE_SHORT : Int = 18;  // fc short noise  
    public static inline var PG_NOISE_HIPAS : Int = 19;  // high pass noise  
    public static inline var PG_NOISE_PINK : Int = 20;  // pink noise  
    public static inline var PG_NOISE_GB_SHORT : Int = 21;  // gb short noise  
    // ( 22-  23) reserved
    public static inline var PG_PC_NZ_16BIT : Int = 24;  // pitch controlable periodic noise  
    public static inline var PG_PC_NZ_SHORT : Int = 25;  // pitch controlable 93byte noise  
    public static inline var PG_PC_NZ_OPM : Int = 26;  // pulse noise with OPM noise table  
    // ( 27-  31) reserved
    public static inline var PG_MA3_WAVE : Int = 32;  // ( 32-  63) MA3 waveforms.  PG_MA3_WAVE+[0,31]  
    public static inline var PG_PULSE : Int = 64;  // ( 64-  79) square pulse wave. PG_PULSE+[0,15]  
    public static inline var PG_PULSE_SPIKE : Int = 80;  // ( 80-  95) square pulse wave. PG_PULSE_SPIKE+[0,15]  
    // ( 96- 127) reserved
    public static inline var PG_RAMP : Int = 128;  // (128- 255) ramp wave. PG_RAMP+[0,127]  
    public static inline var PG_CUSTOM : Int = 256;  // (256- 383) custom wave table. PG_CUSTOM+[0,127]  
    public static inline var PG_PCM : Int = 384;  // (384- 511) pcm data. PG_PCM+[0,128]  
    public static var PG_USER_CUSTOM : Int = -1;  // -1 user registered custom wave table  
    public static var PG_USER_PCM : Int = -2;  // -2 user registered pcm data  
    
    public static inline var DEFAULT_PG_MAX : Int = 256;  // max value of pgType = 255  
    public static inline var PG_FILTER : Int = 511;  // pg number loops between 0 to 511  
    
    public static inline var WAVE_TABLE_MAX : Int = 128;  // custom wave table max.  
    public static inline var PCM_DATA_MAX : Int = 128;  // pcm data max.  
    public static inline var SAMPLER_TABLE_MAX : Int = 4;  // sampler table max  
    public static var SAMPLER_DATA_MAX : Int = NOTE_TABLE_SIZE;  // sampler data max  
    
    public static inline var VM_LINEAR : Int = 0;  // linear scale  
    public static inline var VM_DR96DB : Int = 1;  // log scale; dynamic range = 96dB  
    public static inline var VM_DR64DB : Int = 2;  // log scale; dynamic range = 64dB  
    public static inline var VM_DR48DB : Int = 3;  // log scale; dynamic range = 48dB  
    public static inline var VM_DR32DB : Int = 4;  // log scale; dynamic range = 32dB  
    public static inline var VM_MAX : Int = 5;
    
    
    // lfo wave type
    public static inline var LFO_WAVE_SAW : Int = 0;
    public static inline var LFO_WAVE_SQUARE : Int = 1;
    public static inline var LFO_WAVE_TRIANGLE : Int = 2;
    public static inline var LFO_WAVE_NOISE : Int = 3;
    public static inline var LFO_WAVE_MAX : Int = 8;
    
    
    
    
    // tables
    //--------------------------------------------------
    /** EG:increment table. This table is based on MAME's opm emulation. */
    public var eg_incTables : Array<Dynamic> = [  // eg_incTables[19][8]  
        /*cycle:              0 1  2 3  4 5  6 7  */
        /* 0*/[0, 1, 0, 1, 0, 1, 0, 1],   /* rates 00..11 0 (increment by 0 or 1) */  
        /* 1*/[0, 1, 0, 1, 1, 1, 0, 1],   /* rates 00..11 1 */  
        /* 2*/[0, 1, 1, 1, 0, 1, 1, 1],   /* rates 00..11 2 */  
        /* 3*/[0, 1, 1, 1, 1, 1, 1, 1],   /* rates 00..11 3 */  
        /* 4*/[1, 1, 1, 1, 1, 1, 1, 1],   /* rate 12 0 (increment by 1) */  
        /* 5*/[1, 1, 1, 2, 1, 1, 1, 2],   /* rate 12 1 */  
        /* 6*/[1, 2, 1, 2, 1, 2, 1, 2],   /* rate 12 2 */  
        /* 7*/[1, 2, 2, 2, 1, 2, 2, 2],   /* rate 12 3 */  
        /* 8*/[2, 2, 2, 2, 2, 2, 2, 2],   /* rate 13 0 (increment by 2) */  
        /* 9*/[2, 2, 2, 4, 2, 2, 2, 4],   /* rate 13 1 */  
        /*10*/[2, 4, 2, 4, 2, 4, 2, 4],   /* rate 13 2 */  
        /*11*/[2, 4, 4, 4, 2, 4, 4, 4],   /* rate 13 3 */  
        /*12*/[4, 4, 4, 4, 4, 4, 4, 4],   /* rate 14 0 (increment by 4) */  
        /*13*/[4, 4, 4, 8, 4, 4, 4, 8],   /* rate 14 1 */  
        /*14*/[4, 8, 4, 8, 4, 8, 4, 8],   /* rate 14 2 */  
        /*15*/[4, 8, 8, 8, 4, 8, 8, 8],   /* rate 14 3 */  
        /*16*/[8, 8, 8, 8, 8, 8, 8, 8],   /* rates 15 0, 15 1, 15 2, 15 3 (increment by 8) */  
        /*17*/[0, 0, 0, 0, 0, 0, 0, 0]  /* infinity rates for attack and decay(s) */  ];
    /** EG:increment table for attack. This shortcut is based on fmgen (shift=0 means x0). */
    public var eg_incTablesAtt : Array<Dynamic> = [
        /*cycle:              0 1  2 3  4 5  6 7  */
        /* 0*/[0, 4, 0, 4, 0, 4, 0, 4],   /* rates 00..11 0 (increment by 0 or 1) */  
        /* 1*/[0, 4, 0, 4, 4, 4, 0, 4],   /* rates 00..11 1 */  
        /* 2*/[0, 4, 4, 4, 0, 4, 4, 4],   /* rates 00..11 2 */  
        /* 3*/[0, 4, 4, 4, 4, 4, 4, 4],   /* rates 00..11 3 */  
        /* 4*/[4, 4, 4, 4, 4, 4, 4, 4],   /* rate 12 0 (increment by 1) */  
        /* 5*/[4, 4, 4, 3, 4, 4, 4, 3],   /* rate 12 1 */  
        /* 6*/[4, 3, 4, 3, 4, 3, 4, 3],   /* rate 12 2 */  
        /* 7*/[4, 3, 3, 3, 4, 3, 3, 3],   /* rate 12 3 */  
        /* 8*/[3, 3, 3, 3, 3, 3, 3, 3],   /* rate 13 0 (increment by 2) */  
        /* 9*/[3, 3, 3, 2, 3, 3, 3, 2],   /* rate 13 1 */  
        /*10*/[3, 2, 3, 2, 3, 2, 3, 2],   /* rate 13 2 */  
        /*11*/[3, 2, 2, 2, 3, 2, 2, 2],   /* rate 13 3 */  
        /*12*/[2, 2, 2, 2, 2, 2, 2, 2],   /* rate 14 0 (increment by 4) */  
        /*13*/[2, 2, 2, 1, 2, 2, 2, 1],   /* rate 14 1 */  
        /*14*/[2, 8, 2, 1, 2, 1, 2, 1],   /* rate 14 2 */  
        /*15*/[2, 1, 1, 1, 2, 1, 1, 1],   /* rate 14 3 */  
        /*16*/[1, 1, 1, 1, 1, 1, 1, 1],   /* rates 15 0, 15 1, 15 2, 15 3 (increment by 8) */  
        /*17*/[0, 0, 0, 0, 0, 0, 0, 0]  /* infinity rates for attack and decay(s) */  ];
    /** EG:table selector. */
    public var eg_tableSelector : Array<Dynamic> = null;
    /** EG:table to calculate eg_level. */
    public var eg_levelTables : Array<Array<Int>> = null;
    /** EG:table from sgg_type to eg_levelTables index. */
    public var eg_ssgTableIndex : Array<Dynamic> = null;
    /** EG:timer step. */
    public var eg_timerSteps : Array<Dynamic> = null;
    /** EG:sl table from 15 to 1024. */
    public var eg_slTable : Array<Dynamic> = null;
    /** EG:tl table from volume to tl. */
    public var eg_tlTables : Array<Array<Int>> = null;
    /** EG:tl table from linear volume. */
    public var eg_tlTableLine : Array<Int> = null;
    /** EG:tl table of tl based. */
    public var eg_tlTable96dB : Array<Int> = null;
    /** EG:tl table of fmp7 based. */
    public var eg_tlTable64dB : Array<Int> = null;
    /** EG:tl table from psg volume. */
    public var eg_tlTable48dB : Array<Int> = null;
    /** EG:tl table from N88 basic v command. */
    public var eg_tlTable32dB : Array<Int> = null;
    /** EG:tl table from linear-volume to tl. */
    public var eg_lv2tlTable : Array<Int> = null;
    
    /** LFO:timer step. */
    public var lfo_timerSteps : Array<Int> = null;
    /** LFO:lfo modulation table */
    public var lfo_waveTables : Array<Array<Int>> = null;
    /** LFO:lfo modulation table for chorus */
    public var lfo_chorusTables : Array<Int> = null;
    
    /** FILTER: cutoff */
    public var filter_cutoffTable : Array<Float> = null;
    /** FILTER: resonance */
    public var filter_feedbackTable : Array<Float> = null;
    /** FILTER: envlop rate */
    public var filter_eg_rate : Array<Int> = null;
    
    /** PG:pitch table. */
    public var pitchTable : Array<Array<Int>> = null;
    /** PG:phase step shift filter. */
    public var phaseStepShiftFilter : Array<Int> = null;
    /** PG:log table. */
    public var logTable : Array<Int> = null;
    /** PG:MIDI note number to FM key code. */
    public var nnToKC : Array<Int> = null;
    /** PG:pitch wave length (in samples) table. */
    public var pitchWaveLength : Array<Float> = null;
    /** PG:Wave tables without any waves. */
    public var noWaveTable : SiOPMWaveTable;
    public var noWaveTableOPM : SiOPMWaveTable;
    
    /** PG:Sound reference table */
    public var soundReference : Map<String, Dynamic> = null;
    /** PG:Wave tables */
    public var waveTables : Array<SiOPMWaveTable> = null;
    /** PG:Sampler table */
    public var samplerTables : Array<SiOPMWaveSamplerTable> = null;
    /** PG:Custom wave tables */
    private var _customWaveTables : Array<SiOPMWaveTable> = null;
    /** PG:Overriding custom wave tables */
    public var _stencilCustomWaveTables : Array<SiOPMWaveTable> = null;
    /** PG:PCM voice */
    private var _pcmVoices : Array<SiMMLVoice> = null;
    /** PG:PCM voice */
    public var _stencilPCMVoices : Array<SiMMLVoice> = null;
    
    /** Table for dt1 (from fmgen.cpp). */
    public var dt1Table : Array<Dynamic> = null;
    /** Table for dt2 (from MAME's opm source). */
    public var dt2Table : Array<Int> = [0, 384, 500, 608];
    
    /** Flags of final oscillator */
    public var final_oscilator_flags : Array<Dynamic> = [[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 
        [2, 3, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 
        [4, 4, 5, 6, 6, 7, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0], 
        [8, 8, 8, 8, 10, 14, 14, 15, 9, 13, 8, 9, 9, 0, 0, 0]];
    
    /** int->Number ratio on pulse data */
    public var i2n : Float;
    /** Panning volume table. */
    public var panTable : Array<Float> = null;
    
    /** sampling rate */
    public var rate : Int;
    /** fm clock */
    public var clock : Int;
    /** psg clock */
    public var psg_clock : Float;
    /** (clock/64/sampling_rate)&lt;&lt;CLOCK_RATIO_BITS */
    public var clock_ratio : Int;
    /** 44100Hz=0, 22050Hz=1 */
    public var sampleRatePitchShift : Int;
    
    
    
    
    // static public instance
    //--------------------------------------------------
    /** internal instance, you can access this after creating SiONDriver. */
    public static var _instance : SiOPMTable = null;
    
    
    /** static sigleton instance */
    private static function get_instance() : SiOPMTable
    {
        if (_instance == null) {
            _instance = new SiOPMTable(3580000, 1789772.5, 44100);
        }
        return _instance;
    }
    
    
    
    
    // constructor
    //--------------------------------------------------
    /** constructor
     *  @param clock FM module's clock.
     *  @param rate Sampling rate of wave data
     */
    public function new(clock : Int, psg_clock : Float, rate : Int)
    {
        _setConstants(clock, psg_clock, rate);
        _createEGTables();
        _createPGTables();
        _createWaveSamples();
        _createLFOTables();
        _createFilterTables();
    }
    
    
    // calculate constants
    //--------------------------------------------------
    private function _setConstants(clock : Int, psg_clock : Float, rate : Int) : Void
    {
        this.clock = clock;
        this.psg_clock = psg_clock;
        this.rate = rate;
        sampleRatePitchShift = ((rate == 44100)) ? 0 : ((rate == 22050)) ? 1 : -1;
        if (sampleRatePitchShift == -1)             throw new Error("SiOPMTable error : Sampling rate (" + rate + ") is not supported.");
        clock_ratio = Math.floor((Math.floor(clock / 64) << CLOCK_RATIO_BITS) / rate);
        
        // int->Number ratio on pulse data
        i2n = OUTPUT_MAX / (1 << LOG_VOLUME_BITS);
    }
    
    
    // calculate EG tables
    //--------------------------------------------------
    private function _createEGTables() : Void
    {
        var i : Int;
        var j : Int;
        var imax : Int;
        var imax2 : Int;
        var table : Array<Dynamic>;

        // 128 = 64rates + 32ks-rates + 32dummies for dr,sr=0
        eg_timerSteps = new Array<Int>();
        eg_tableSelector = new Array<Int>();
        
        i = 0;
        while (i < 44) {  // rate = 0-43
            eg_timerSteps[i] = Math.floor((1 << (i >> 2)) * clock_ratio);
            eg_tableSelector[i] = (i & 3);
            i++;
        }
        while (i < 48) {  // rate = 44-47
            eg_timerSteps[i] = Math.floor(2047 * clock_ratio);
            eg_tableSelector[i] = (i & 3);
            i++;
        }
        while (i < 60) {  // rate = 48-59
            eg_timerSteps[i] = Math.floor(2047 * clock_ratio);
            eg_tableSelector[i] = i - 44;
            i++;
        }
        while (i < 96) {  // rate = 60-95 (rate=60-95 are same as rate=63(maximum))
            eg_timerSteps[i] = Math.floor(2047 * clock_ratio);
            eg_tableSelector[i] = 16;
            i++;
        }
         while(i < 128) {  // rate = 96-127 (dummies for ar,dr,sr=0)
            eg_timerSteps[i] = 0;
            eg_tableSelector[i] = 17;
            i++;
        }

        // table for ssgenv
        imax = (1 << ENV_BITS);
        imax2 = imax >> 2;
        eg_levelTables = new Array<Array<Int>>();
        for (i in 0...7) {
            eg_levelTables[i] = new Array<Int>();
        }
        for (i in 0...imax2) {
            eg_levelTables[0][i] = i;  // normal table  
            eg_levelTables[1][i] = i << 2;  // ssg positive  
            eg_levelTables[2][i] = 512 - (i << 2);  // ssg negative  
            eg_levelTables[3][i] = 512 + (i << 2);  // ssg positive + offset  
            eg_levelTables[4][i] = 1024 - (i << 2);  // ssg negative + offset  
            eg_levelTables[5][i] = 0;  // ssg fixed at max  
            eg_levelTables[6][i] = 1024;
        }
        for (i in imax2...imax){
            eg_levelTables[0][i] = i;  // normal table  
            eg_levelTables[1][i] = 1024;  // ssg positive  
            eg_levelTables[2][i] = 0;  // ssg negative  
            eg_levelTables[3][i] = 1024;  // ssg positive + offset  
            eg_levelTables[4][i] = 512;  // ssg negative + offset  
            eg_levelTables[5][i] = 0;  // ssg fixed at max  
            eg_levelTables[6][i] = 1024;
        }
        
        eg_ssgTableIndex = new Array<Dynamic>();
                            //[[w/   ar], [w/o  ar]]
        eg_ssgTableIndex[0] = [[3, 3, 3], [1, 3, 3]];  // ssgec=8  
        eg_ssgTableIndex[1] = [[1, 6, 6], [1, 6, 6]];  // ssgec=9  
        eg_ssgTableIndex[2] = [[2, 1, 2], [1, 2, 1]];  // ssgec=10  
        eg_ssgTableIndex[3] = [[2, 5, 5], [1, 5, 5]];  // ssgec=11  
        eg_ssgTableIndex[4] = [[4, 4, 4], [2, 4, 4]];  // ssgec=12  
        eg_ssgTableIndex[5] = [[2, 5, 5], [2, 5, 5]];  // ssgec=13  
        eg_ssgTableIndex[6] = [[1, 2, 1], [2, 1, 2]];  // ssgec=14  
        eg_ssgTableIndex[7] = [[1, 6, 6], [2, 6, 6]];  // ssgec=15  
        eg_ssgTableIndex[8] = [[1, 1, 1], [1, 1, 1]];  // ssgec=8+  
        eg_ssgTableIndex[9] = [[2, 2, 2], [2, 2, 2]];  // ssgec=12+  
        
        // sl(15) -> sl(1023)
        eg_slTable = new Array<Int>();
        for (i in 0...15){
            eg_slTable[i] = i << 5;
        }
        eg_slTable[15] = 31 << 5;
        
        //var n88vtable:Array = [104, 40, 37, 34, 32, 29, 26, 24, 21, 18, 16, 13, 10, 8, 5, 2, 0];
        eg_tlTables = new Array<Array<Int>>();
        eg_tlTables[VM_LINEAR] = eg_tlTableLine = new Array<Int>();
        eg_tlTables[VM_DR96DB] = eg_tlTable96dB = new Array<Int>();
        eg_tlTables[VM_DR64DB] = eg_tlTable64dB = new Array<Int>();
        eg_tlTables[VM_DR48DB] = eg_tlTable48dB = new Array<Int>();
        eg_tlTables[VM_DR32DB] = eg_tlTable32dB = new Array<Int>();
        
        // v(0-256) -> total_level(832- 0). translate linear volume to log scale gain.
        eg_tlTableLine[0] = eg_tlTable96dB[0] = eg_tlTable48dB[0] = eg_tlTable32dB[0] = ENV_BOTTOM;
        for (i in 1...257){
            // 0.00390625 = 1/256
            eg_tlTableLine[i] = calcLogTableIndex(i * 0.00390625) >> (LOG_VOLUME_BITS - ENV_BITS);
            eg_tlTable96dB[i] = (256 - i) * 4;  //  (n/2)<<ENV_LSHIFT  
            eg_tlTable64dB[i] = Math.floor((256 - i) * 2.6666666666666667);  // ((n/2)<<ENV_LSHIFT)*2/3  
            eg_tlTable48dB[i] = (256 - i) * 2;  // ((n/2)<<ENV_LSHIFT)*1/2  
            eg_tlTable32dB[i] = Math.floor((256 - i) * 1.333333333333333);
        }

        // v(257-448) -> total_level(0 - -192). distortion.
        for (i in 1...193){
            j = i + 256;
            eg_tlTableLine[j] = eg_tlTable96dB[j] = eg_tlTable64dB[j] = eg_tlTable48dB[j] = eg_tlTable32dB[j] = -i;
        }

        // v(449-512) -> total_level=-192. distortion.
        for (i in 1...65){
            j = i + 448;
            eg_tlTableLine[j] = eg_tlTable96dB[j] = eg_tlTable64dB[j] = eg_tlTable48dB[j] = eg_tlTable32dB[j] = ENV_TOP;
        }

        // table from linear volume to tl
        eg_lv2tlTable = new Array<Int>();
        for (i in 0...129){
            eg_lv2tlTable[i] = calcLogTableIndex(i * 0.0078125) >> (LOG_VOLUME_BITS - ENV_BITS + ENV_LSHIFT);
        }

        // panning volume table
        panTable = new Array<Float>();
        for (i in 0...129){
            panTable[i] = Math.sin(i * 0.01227184630308513);
        }
    }
    
    
    // calculate PG tables
    //--------------------------------------------------
    private function _createPGTables() : Void
    {
        // multipurpose
        var i : Int;
        var imax : Int;
        var p : Float;
        var dp : Float;
        var n : Float;
        var j : Int;
        var jmax : Int;
        var v : Float;
        var iv : Int = 0;
        var table : Array<Int>;
        
        
        // MIDI Note Number -> Key Code table
        //----------------------------------------
        nnToKC = new Array<Int>();
        i = 0;
        j = 0;
        while (j < NOTE_TABLE_SIZE){
            nnToKC[j] = ((i < 16)) ? i : ((i >= KEY_CODE_TABLE_SIZE)) ? (KEY_CODE_TABLE_SIZE - 1) : (i - 16);
            i++;
            j = i - (i >> 2);
        }

        //----------------------------------------    // pitch table
        imax = HALF_TONE_RESOLUTION * 12;  // 12=1octave
        jmax = PITCH_TABLE_SIZE;
        dp = 1 / imax;
        
        // wave length table
        pitchWaveLength = new Array<Float>();
        n = rate / 8.175798915643707;  // = 5393.968278209282@44.1kHz sampling count @ MIDI note number = 0  
        i = 0;
        p = 0;
        while (i < imax){
            v = Math.pow(2, -p) * n;
            j = i;
            while (j < jmax){
                pitchWaveLength[j] = v;
                v *= 0.5;
                j += imax;
            }
            i++;
            p += dp;
        }

        // phase step tables
        pitchTable = new Array<Array<Int>>();
        phaseStepShiftFilter = new Array<Int>();
        
        // OPM
        table = new Array<Int>();
        n = 8.175798915643707 * PHASE_MAX / rate;  // dphase @ MIDI note number = 0  
        i = 0;
        p = 0;
        while (i < imax){
            v = Math.pow(2, p) * n;
            j = i;
            while (j < jmax){
                table[j] = Math.floor(v);
                v *= 2;
                j += imax;
            }
            i++;
            p += dp;
        }
        pitchTable[PT_OPM] = table;
        phaseStepShiftFilter[PT_OPM] = 0;
        
        // PCM
        // dphase = pitchTablePCM[pitchIndex] >> (table_size (= PHASE_BITS - waveTable.fixedBits))
        table = new Array<Int>();
        n = 0.01858136117191752 * PHASE_MAX;  // dphase @ MIDI note number = 0/ o0c=0.01858136117191752 -> o5a=1  
        i = 0;
        p = 0;
        while (i < imax){
            v = Math.pow(2, p) * n;
            j = i;
            while (j < jmax){
                table[j] = Math.floor(v);
                v *= 2;
                j += imax;
            }
            i++;
            p += dp;
        }
        pitchTable[PT_PCM] = table;
        phaseStepShiftFilter[PT_PCM] = 0xffffffff;
        
        // PSG(table_size = 16)
        table = new Array<Int>();
        n = psg_clock * (PHASE_MAX >> 4) / rate;
        i = 0;
        p = 0;
        while (i < imax){
            // 8.175798915643707 = [frequency @ MIDI note number = 0]
            // 130.8127826502993 = 8.175798915643707 * 16
            v = psg_clock / (Math.pow(2, p) * 130.8127826502993);
            j = i;
            while (j < jmax){
                // register value
                iv = Math.floor(v + 0.5);
                if (iv > 4096)                     iv = 4096;
                table[j] = Math.floor(n / iv);
                v *= 0.5;
                j += imax;
            }
            i++;
            p += dp;
        }
        pitchTable[PT_PSG] = table;
        phaseStepShiftFilter[PT_PSG] = 0;
        
        /*
        // APU DPCM period table
        var fc_df:Array = [428, 380, 340, 320, 286, 254, 226, 214, 190, 160, 142, 128, 106, 85, 72, 54];
        imax  = 16<<HALF_TONE_BITS;
        table = new Vector.<int>(imax, true);
        n = psg_clock/(rate*0.018581361171917529);
        for (i=0; i<16; i++) {
        iv = Math.log(n / fc_df[i]) * 1.4426950408889633 * PHASE_MAX / rate;
        for (j=0; j<HALF_TONE_RESOLUTION; j++) {
        table[(i<<HALF_TONE_BITS)+j] = iv;
        }
        }
        pitchTable[PT_APU_DPCM] = table;
        phaseStepShiftFilter[PT_APU_DPCM] = 0xffffffff;
        */
        
        // Noise period tables.
        //----------------------------------------
        // OPM noise period table.
        // noise_phase_shift = pitchTable[PT_OPM_NOISE][noiseFreq] >> (PHASE_BITS - waveTable.fixedBits).
        imax = 32 << HALF_TONE_BITS;
        table = new Array<Int>();
        n = PHASE_MAX * clock_ratio;  // clock_ratio = ((clock/64)/rate) << CLOCK_RATIO_BITS  
        for (i in 0...31){
            iv = (Math.floor(n / ((32 - i) * 0.5))) >> CLOCK_RATIO_BITS;
            for (j in 0...HALF_TONE_RESOLUTION) {
                table[(i << HALF_TONE_BITS) + j] = iv;
            }
        }
        for (i in 31<<HALF_TONE_BITS...imax) {
            table[i] = iv;
        }
        pitchTable[PT_OPM_NOISE] = table;
        phaseStepShiftFilter[PT_OPM_NOISE] = 0xffffffff;
        
        // PSG noise period table.
        table = new Array<Int>();
        // noise_phase_shift = ((1<<PHASE_BIT)  /  ((nf/(clock/16))[sec]  /  (1/44100)[sec])) >> (PHASE_BIT - waveTable.fixedBits)
        n = PHASE_MAX * clock / (rate * 16);
        for (i in 0...32){
            iv = Math.floor(n / i);
            for (j in 0...HALF_TONE_RESOLUTION){
                table[(i << HALF_TONE_BITS) + j] = iv;
            }
        }
        pitchTable[PT_PSG_NOISE] = table;
        phaseStepShiftFilter[PT_PSG_NOISE] = 0xffffffff;
        
        // APU noise period table
        var fc_nf : Array<Dynamic> = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068];
        imax = 16 << HALF_TONE_BITS;
        table = new Array<Int>();
        // noise_phase_shift = ((1<<PHASE_BIT)  /  ((nf/clock)[sec]  /  (1/44100)[sec])) >> (PHASE_BIT - waveTable.fixedBits)
        n = PHASE_MAX * psg_clock / rate;
        for (i in 0...16){
            iv = Math.floor(n / fc_nf[i]);
            for (j in 0...HALF_TONE_RESOLUTION){
                table[(i << HALF_TONE_BITS) + j] = iv;
            }
        }
        pitchTable[PT_APU_NOISE] = table;
        phaseStepShiftFilter[PT_APU_NOISE] = 0xffffffff;
        
        // Game boy noise period
        var gb_nf : Array<Dynamic> = [2, 4, 8, 12, 16, 20, 24, 28, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384, 448, 512, 640, 768, 896, 1024, 1280, 1536, 1792, 
        2048, 2560, 3072, 3584, 4096, 5120, 6144, 7168, 8192, 10240, 12288, 14336, 16384, 20480, 24576, 28672, 
        32768, 40960, 49152, 57344, 65536, 81920, 98304, 114688, 131072, 163840, 196608, 229376, 262144, 327680, 393216, 458752];
        imax = 64 << HALF_TONE_BITS;
        table = new Array<Int>();
        // noise_phase_shift = ((1<<PHASE_BIT)  /  ((nf/clock)[sec]  /  (1/44100)[sec])) >> (PHASE_BIT - waveTable.fixedBits)
        n = PHASE_MAX * 1048576 / rate;  // gb clock = 1048576  
        for (i in 0...64) {
            iv = Math.floor(n / gb_nf[i]);
            for (j in 0...HALF_TONE_RESOLUTION) {
                table[(i << HALF_TONE_BITS) + j] = iv;
            }
        }
        pitchTable[PT_GB_NOISE] = table;
        phaseStepShiftFilter[PT_GB_NOISE] = 0xffffffff;
        
        
        // dt1 table
        //----------------------------------------
        // dt1 table from X68Sound.dll
        var fmgen_dt1 : Array<Dynamic> = [  //[4][32]  
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 
        [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 8, 8, 8], 
        [1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 10, 11, 12, 13, 14, 16, 16, 16, 16], 
        [2, 2, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 6, 6, 7, 8, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 20, 22, 22, 22, 22]];
        dt1Table = new Array<Array<Int>>();
        for (i in 0...4){
            dt1Table[i] = new Array<Int>();
            dt1Table[i + 4] = new Array<Int>();
            for (j in 0...KEY_CODE_TABLE_SIZE){
                iv = (Math.floor(fmgen_dt1[i][j >> 2]) * 64 * clock_ratio) >> CLOCK_RATIO_BITS;
                dt1Table[i][j] = iv;
                dt1Table[i + 4][j] = -iv;
            }
        }

        // log table
        // ----------------------------------------
        logTable = new Array<Int>();  // *3(2more zerofillarea) 16*256*2*3 = 24576
        i = (-ENV_TOP) << 3;  // start at -ENV_TOP  
        imax = i + LOG_TABLE_RESOLUTION * 2;  // *2(posi&nega)  
        jmax = LOG_TABLE_SIZE;
        dp = 1 / LOG_TABLE_RESOLUTION;
        p = dp;
        while (i < imax) {
            v = Math.pow(2, LOG_VOLUME_BITS - p);  // v=2^(LOG_VOLUME_BITS-1/256) at maximum (i=2)  
            j = i;
            while (j < jmax) {
                iv = Math.floor(v);
                logTable[j] = iv;
                logTable[j + 1] = -iv;
                v *= 0.5;
                j += LOG_TABLE_RESOLUTION * 2;
            }
            i += 2;
            p += dp;
        }  // satulation area  
        
        imax = (-ENV_TOP) << 3;
        iv = logTable[imax];
        i = 0;
        while (i < imax){
            logTable[i] = iv;
            logTable[i + 1] = -iv;
            i += 2;
        }  // zero fill area  
        
        imax = logTable.length;
        for (i in jmax...imax) {
            logTable[i] = Math.floor(0);
        }
    }
    
    
    // calculate wave samples
    //--------------------------------------------------
    private function _createWaveSamples() : Void
    {
        // multipurpose
        var i : Int;
        var imax : Int;
        var imax2 : Int;
        var imax3 : Int;
        var imax4 : Int;
        var j : Int;
        var jmax : Int;
        var p : Float;
        var dp : Float;
        var n : Float;
        var v : Float;
        var iv : Int;
        var prev : Int = 0;
        var o : Int;
        var table1 : Array<Int>;
        var table2 : Array<Int>;
        
        // allocate table list
        noWaveTable = SiOPMWaveTable.alloc([calcLogTableIndex(1)], PT_PCM);
        noWaveTableOPM = SiOPMWaveTable.alloc([calcLogTableIndex(1)], PT_OPM);
        waveTables = new Array<SiOPMWaveTable>();
        samplerTables = new Array<SiOPMWaveSamplerTable>();
        _customWaveTables = new Array<SiOPMWaveTable>();
        _pcmVoices = new Array<SiMMLVoice>();
        
        // clear all tables
        //------------------------------
        for (i in 0...DEFAULT_PG_MAX) {
            waveTables[i] = noWaveTable;
        }
        for (i in 0...WAVE_TABLE_MAX) {
            _customWaveTables[i] = null;
        }
        for (i in 0...PCM_DATA_MAX) {
            _pcmVoices[i] = null;
        }
        for (i in 0...SAMPLER_TABLE_MAX) {
            samplerTables[i] = (new SiOPMWaveSamplerTable()).clear();
        }
        
        _stencilCustomWaveTables = null;
        _stencilPCMVoices = null;
        
        // sine wave table
        //------------------------------
        table1 = new Array<Int>();
        dp = 6.283185307179586 / SAMPLING_TABLE_SIZE;
        imax = SAMPLING_TABLE_SIZE >> 1;
        imax2 = SAMPLING_TABLE_SIZE;
        i = 0;
        p = dp * 0.5;
        while (i < imax){
            iv = calcLogTableIndex(Math.sin(p));
            table1[i] = iv;  // positive index  
            table1[i + imax] = iv + 1;
            i++;
            p += dp;
        }
        waveTables[PG_SINE] = SiOPMWaveTable.alloc(table1);
        
        // saw wave tables
        //------------------------------
        table1 = new Array<Int>();
        table2 = new Array<Int>();
        dp = 1 / imax;
        i = 0;
        p = dp * 0.5;
        while (i < imax){
            iv = calcLogTableIndex(p);
            table1[i] = iv;  // positive  
            table1[imax2 - i - 1] = iv + 1;  // negative  
            table2[imax - i - 1] = iv;  // positive  
            table2[imax + i] = iv + 1;
            i++;
            p += dp;
        }
        waveTables[PG_SAW_UP] = SiOPMWaveTable.alloc(table1);
        waveTables[PG_SAW_DOWN] = SiOPMWaveTable.alloc(table2);
        table1 = new Array<Int>();
        i = 0;
        p = -0.96875;
        while (i < 32){
            table1[i] = calcLogTableIndex(p);
            i++;
            p += 0.0625;
        }
        waveTables[PG_SAW_VC6] = SiOPMWaveTable.alloc(table1);
        
        // triangle wave tables
        //------------------------------
        // triangle wave
        table1 = new Array<Int>();
        imax = SAMPLING_TABLE_SIZE >> 2;
        imax2 = SAMPLING_TABLE_SIZE >> 1;
        imax4 = SAMPLING_TABLE_SIZE;
        dp = 1 / imax;
        i = 0;
        p = dp * 0.5;
        while (i < imax){
            iv = calcLogTableIndex(p);
            table1[i] = iv;  // positive index  
            table1[imax2 - i - 1] = iv;  // positive index  
            table1[imax2 + i] = iv + 1;  // negative value index  
            table1[imax4 - i - 1] = iv + 1;
            i++;
            p += dp;
        }
        waveTables[PG_TRIANGLE] = SiOPMWaveTable.alloc(table1);
        
        // fc triangle wave
        table1 = new Array<Int>();
        i = 1;
        p = 0.125;
        while (i < 8){
            iv = calcLogTableIndex(p);
            table1[i] = iv;
            table1[15 - i] = iv;
            table1[15 + i] = iv + 1;
            table1[32 - i] = iv + 1;
            i++;
            p += 0.125;
        }
        table1[0] = LOG_TABLE_BOTTOM;
        table1[15] = LOG_TABLE_BOTTOM;
        table1[23] = 3;
        table1[24] = 3;
        waveTables[PG_TRIANGLE_FC] = SiOPMWaveTable.alloc(table1);
        
        // square wave tables
        //----------------------------
        // 50% square wave
        iv = calcLogTableIndex(SQUARE_WAVE_OUTPUT);
        waveTables[PG_SQUARE] = SiOPMWaveTable.alloc([iv, iv + 1]);
        
        
        // pulse wave tables
        //----------------------------
        // pulse wave
        // NOTE: The resolution of duty ratio is twice than pAPU. [pAPU pulse wave table] = waveTables[PG_PULSE+duty*2].
        table2 = waveTables[PG_SQUARE].wavelet;
        for (j in 0...16) {
            table1 = new Array<Int>();
            for (i in 0...16) {
                table1[i] = ((i < j)) ? table2[0] : table2[1];
            }
            waveTables[PG_PULSE + j] = SiOPMWaveTable.alloc(table1);
        }

        // spike pulse
        iv = calcLogTableIndex(0);
        for (j in 0...16) {
            table1 = new Array<Int>();
            imax = j << 1;
            for (i in 0...imax) {
                table1[i] = ((i < j)) ? table2[0] : table2[1];
            }
            while (i < 32) {
                table1[i] = iv;
                i++;
            }
            waveTables[PG_PULSE_SPIKE + j] = SiOPMWaveTable.alloc(table1);
        }  //----------------------------    // wave from konami bubble system  
        
        
        
        
        
        
        var wav : Array<Dynamic> = [-80, -112, -16, 96, 64, 16, 64, 96, 32, -16, 64, 112, 80, 0, 32, 48, -16, -96, 0, 80, 16, -64, -48, -16, -96, -128, -80, 0, -48, -112, -80, -32];
        table1 = new Array<Int>();
        for (i in 0...32){
            table1[i] = calcLogTableIndex(wav[i] / 128);
        }
        waveTables[PG_KNMBSMM] = SiOPMWaveTable.alloc(table1);
        
        
        // pseudo sync
        //----------------------------
        table1 = new Array<Int>();
        table2 = new Array<Int>();
        imax = SAMPLING_TABLE_SIZE;
        dp = 1 / imax;
        i = 0;
        p = dp * 0.5;
        while (i < imax){
            iv = calcLogTableIndex(p);
            table1[i] = iv + 1;  // negative  
            table2[i] = iv;
            i++;
            p += dp;
        }
        waveTables[PG_SYNC_LOW] = SiOPMWaveTable.alloc(table1);
        waveTables[PG_SYNC_HIGH] = SiOPMWaveTable.alloc(table2);
        
        
        // noise tables
        //------------------------------
        // white noise
        // pulse noise. NOTE: Dishonest impelementation. Details are shown in MAME or VirtuaNes source.
        table1 = new Array<Int>();
        table2 = new Array<Int>();
        imax = NOISE_TABLE_SIZE;
        iv = calcLogTableIndex(NOISE_WAVE_OUTPUT);
        n = NOISE_WAVE_OUTPUT / 32768;
        j = 1;  // 15bit LFSR  
        for (i in 0...imax) {
            j = (((j << 13) ^ (j << 14)) & 0x4000) | (j >> 1);
            table1[i] = calcLogTableIndex((j & 0x7fff) * n * 2 - 1);
            table2[i] = ((j & 1) != 0) ? iv : (iv + 1);
        }
        waveTables[PG_NOISE_WHITE] = SiOPMWaveTable.alloc(table1, PT_PCM);
        waveTables[PG_NOISE_PULSE] = SiOPMWaveTable.alloc(table2, PT_PCM);
        waveTables[PG_PC_NZ_OPM] = SiOPMWaveTable.alloc(table2, PT_OPM_NOISE);
        waveTables[PG_NOISE] = waveTables[PG_NOISE_WHITE];
        
        // fc short noise. NOTE: Dishonest impelementation. 93*11=1023 aprox.-> 1024.
        table1 = new Array<Int>();
        imax = SAMPLING_TABLE_SIZE;
        iv = calcLogTableIndex(NOISE_WAVE_OUTPUT);
        j = 1;  // 15bit LFSR  
        for (i in 0...imax) {
            j = (((j << 8) ^ (j << 14)) & 0x4000) | (j >> 1);
            table1[i] = ((j & 1) != 0) ? iv : (iv + 1);
        }
        waveTables[PG_NOISE_SHORT] = SiOPMWaveTable.alloc(table1, PT_PCM);
        
        // gb short noise. NOTE:
        table1 = new Array<Int>();
        iv = calcLogTableIndex(NOISE_WAVE_OUTPUT);
        j = 0xffff;  // 16bit LFSR  
        o = 0;
        for (i in 0...128) {
            j += j + (((j >> 6) ^ (j >> 5)) & 1);
            o ^= j & 1;
            table1[i] = ((o & 1) != 0) ? iv : (iv + 1);
        }
        waveTables[PG_NOISE_GB_SHORT] = SiOPMWaveTable.alloc(table1, PT_PCM);
        
        // periodic noise
        table1 = new Array<Int>();
        table1[0] = calcLogTableIndex(SQUARE_WAVE_OUTPUT);
        for (i in 0...16) {
            table1[i] = LOG_TABLE_BOTTOM;
        }
        waveTables[PG_PC_NZ_16BIT] = SiOPMWaveTable.alloc(table1);
        
        // high passed white noise
        table1 = new Array<Int>();
        table2 = waveTables[PG_NOISE_WHITE].wavelet;
        imax = NOISE_TABLE_SIZE;
        j = (-ENV_TOP) << 3;
        n = 16 / (1 << LOG_VOLUME_BITS);
        p = 0.0625;
        trace("HMM!", j, table2[0], NOISE_TABLE_SIZE, table2[NOISE_TABLE_SIZE - 1], p, logTable[table2[0] + j], logTable[table2[NOISE_TABLE_SIZE - 1] + j]);
        v = (logTable[table2[0] + j] - logTable[table2[NOISE_TABLE_SIZE - 1] + j]) * p;
        table1[0] = calcLogTableIndex(v * n);
        for (i in 0...imax) {
            imax2 = table2[i] + j;
            imax3 = table2[i - 1] + j;
            v = (v + logTable[imax2] - logTable[imax3]) * p;
            table1[i] = calcLogTableIndex(v * n);
        }
        waveTables[PG_NOISE_HIPAS] = SiOPMWaveTable.alloc(table1, PT_PCM);
        
        // pink noise
        var b0 : Float = 0;
        var b1 : Float = 0;
        var b2 : Float = 0;
        table1 = new Array<Int>();
        table2 = waveTables[PG_NOISE_WHITE].wavelet;
        imax = NOISE_TABLE_SIZE;
        j = (-ENV_TOP) << 3;
        n = 0.125 / (1 << LOG_VOLUME_BITS);
        for (i in 0...imax) {
            imax2 = table2[i] + j;
            v = logTable[imax2];
            b0 = 0.99765 * b0 + v * 0.0990460;
            b1 = 0.96300 * b1 + v * 0.2965164;
            b2 = 0.57000 * b2 + v * 1.0526913;
            table1[i] = calcLogTableIndex((b0 + b1 + b2 + v * 0.1848) * n);
        }
        waveTables[PG_NOISE_PINK] = SiOPMWaveTable.alloc(table1, PT_PCM);
        
        
        // periodic noise
        table1 = new Array<Int>();
        table1[0] = calcLogTableIndex(SQUARE_WAVE_OUTPUT);
        for (i in 0...16) {
            table1[i] = LOG_TABLE_BOTTOM;
        }
        waveTables[PG_PC_NZ_16BIT] = SiOPMWaveTable.alloc(table1);
        
        
        // pitch controlable noise
        table1 = waveTables[PG_NOISE_SHORT].wavelet;
        table2 = new Array<Int>();
        for (j in 0...SAMPLING_TABLE_SIZE) {
            i = j * 11;
            imax = (((i + 11) < SAMPLING_TABLE_SIZE)) ? (i + 11) : SAMPLING_TABLE_SIZE;
            while (i < imax) {
                table2[i] = table1[j];
                i++;
            }
        }
        waveTables[PG_PC_NZ_SHORT] = SiOPMWaveTable.alloc(table2);
        
        
        // ramp wave tables
        //----------------------------
        // ramp wave
        imax = SAMPLING_TABLE_SIZE;
        imax2 = SAMPLING_TABLE_SIZE >> 1;
        imax4 = SAMPLING_TABLE_SIZE >> 2;
        for (j in 1...60) {
            iv = imax4 >> (j >> 3);
            iv -= (iv * (j & 7)) >> 4;
            if (prev == iv) {
                waveTables[PG_RAMP + 64 - j] = waveTables[PG_RAMP + 65 - j];
                waveTables[PG_RAMP + 64 + j] = waveTables[PG_RAMP + 63 + j];
                continue;
            }
            prev = iv;
            
            table1 = new Array<Int>();
            table2 = new Array<Int>();
            imax3 = imax2 - iv;
            dp = 1 / imax3;
            i = 0;
            p = dp * 0.5;
            while (i < imax3) {
                iv = calcLogTableIndex(p);
                table1[i] = iv;  // positive value  
                table1[imax - i - 1] = iv + 1;  // negative value  
                table2[imax2 + i] = iv + 1;  // negative value  
                table2[imax2 - i - 1] = iv;
                i++;
                p += dp;
            }
            dp = 1 / (imax2 - imax3);
                        while (i < imax2){
                iv = calcLogTableIndex(p);
                table1[i] = iv;  // positive value  
                table1[imax - i - 1] = iv + 1;  // negative value  
                table2[imax2 + i] = iv + 1;  // negative value  
                table2[imax2 - i - 1] = iv;
                i++;
                p -= dp;
            }
            waveTables[PG_RAMP + 64 - j] = SiOPMWaveTable.alloc(table1);
            waveTables[PG_RAMP + 64 + j] = SiOPMWaveTable.alloc(table2);
        }
        for (j in 0...5) {
            waveTables[PG_RAMP + j] = waveTables[PG_SAW_UP];
        }
        for (j in 0...128) {
            waveTables[PG_RAMP + j] = waveTables[PG_SAW_DOWN];
        }
        waveTables[PG_RAMP + 64] = waveTables[PG_TRIANGLE];
        
        
        // MA3 wave tables
        //------------------------------
        // waveform 0-5 = sine wave
        waveTables[PG_MA3_WAVE] = waveTables[PG_SINE];
        __exp_ma3_waves(0);
        // waveform 8-13 = bi-triangle modulated sine ?
        table2 = waveTables[PG_SINE].wavelet;
        table1 = new Array<Int>();
        j = 0;
        for (i in 0...SAMPLING_TABLE_SIZE){
            table1[i] = table2[i + j];
            j += 1 - (((i >> (SAMPLING_TABLE_BITS - 3)) + 1) & 2);
        }
        waveTables[PG_MA3_WAVE + 8] = SiOPMWaveTable.alloc(table1);
        __exp_ma3_waves(8);
        // waveform 16-21 = triangle wave
        waveTables[PG_MA3_WAVE + 16] = waveTables[PG_TRIANGLE];
        __exp_ma3_waves(16);
        // waveform 24-29 = saw wave
        waveTables[PG_MA3_WAVE + 24] = waveTables[PG_SAW_UP];
        __exp_ma3_waves(24);
        // waveform 6 = square
        waveTables[PG_MA3_WAVE + 6] = waveTables[PG_SQUARE];
        // waveform 14 = half square
        iv = calcLogTableIndex(1);
        waveTables[PG_MA3_WAVE + 14] = SiOPMWaveTable.alloc([iv, LOG_TABLE_BOTTOM]);
        // waveform 22 = twice of half square
        waveTables[PG_MA3_WAVE + 22] = SiOPMWaveTable.alloc([iv, LOG_TABLE_BOTTOM, iv, LOG_TABLE_BOTTOM]);
        // waveform 30 = quarter square
        waveTables[PG_MA3_WAVE + 30] = SiOPMWaveTable.alloc([iv, LOG_TABLE_BOTTOM, LOG_TABLE_BOTTOM, LOG_TABLE_BOTTOM]);
        
        // waveform 7 ???
        table1 = new Array<Int>();
        dp = 6.283185307179586 / SAMPLING_TABLE_SIZE;
        imax = SAMPLING_TABLE_SIZE >> 2;
        imax2 = SAMPLING_TABLE_SIZE >> 1;
        imax4 = SAMPLING_TABLE_SIZE;
        i = 0;
        p = dp * 0.5;
        while (i < imax){
            iv = calcLogTableIndex(1 - Math.sin(p));
            table1[i] = iv;  // positive index  
            table1[i + imax] = LOG_TABLE_BOTTOM;
            table1[i + imax2] = LOG_TABLE_BOTTOM;
            table1[imax4 - i - 1] = iv + 1;
            i++;
            p += dp;
        }
        waveTables[PG_MA3_WAVE + 7] = SiOPMWaveTable.alloc(table1);
        // waveform 15,23,31 = custom waveform 0-2 (not available)
        waveTables[PG_MA3_WAVE + 15] = noWaveTable;
        waveTables[PG_MA3_WAVE + 23] = noWaveTable;
        waveTables[PG_MA3_WAVE + 31] = noWaveTable;
    }
    
    
    // expand MA3 waveforms
    private function __exp_ma3_waves(index : Int) : Void
    {
        // multipurpose
        var i : Int;
        var imax : Int;
        var table1 : Array<Int>;
        var table2 : Array<Int>;
        
        // basic waveform
        table2 = waveTables[PG_MA3_WAVE + index].wavelet;
        
        // waveform 1
        table1 = new Array<Int>();
        imax = SAMPLING_TABLE_SIZE >> 1;
        for (i in 0...imax){
            table1[i] = table2[i];
            table1[i + imax] = LOG_TABLE_BOTTOM;
        }
        waveTables[PG_MA3_WAVE + index + 1] = SiOPMWaveTable.alloc(table1);
        
        // waveform 2
        table1 = new Array<Int>();
        imax = SAMPLING_TABLE_SIZE >> 1;
        for (i in 0...imax){
            table1[i] = table2[i];
            table1[i + imax] = table2[i];
        }
        waveTables[PG_MA3_WAVE + index + 2] = SiOPMWaveTable.alloc(table1);
        
        // waveform 3
        table1 = new Array<Int>();
        imax = SAMPLING_TABLE_SIZE >> 2;
        for (i in 0...imax){
            table1[i] = table2[i];
            table1[i + imax] = LOG_TABLE_BOTTOM;
            table1[i + imax * 2] = table2[i];
            table1[i + imax * 3] = LOG_TABLE_BOTTOM;
        }
        waveTables[PG_MA3_WAVE + index + 3] = SiOPMWaveTable.alloc(table1);
        
        // waveform 4
        table1 = new Array<Int>();
        imax = SAMPLING_TABLE_SIZE >> 1;
        for (i in 0...imax){
            table1[i] = table2[i << 1];
            table1[i + imax] = LOG_TABLE_BOTTOM;
        }
        waveTables[PG_MA3_WAVE + index + 4] = SiOPMWaveTable.alloc(table1);
        
        // waveform 5
        table1 = new Array<Int>();
        imax = SAMPLING_TABLE_SIZE >> 2;
        for (i in 0...imax){
            table1[i] = table2[i << 1];
            table1[i + imax] = table1[i];
            table1[i + imax * 2] = LOG_TABLE_BOTTOM;
            table1[i + imax * 3] = LOG_TABLE_BOTTOM;
        }
        waveTables[PG_MA3_WAVE + index + 5] = SiOPMWaveTable.alloc(table1);
    }
    
    
    // calculate LFO tables
    //--------------------------------------------------
    private function _createLFOTables() : Void
    {
        var i : Int;
        var t : Int;
        var s : Int;
        var table : Array<Int>;
        var table2 : Array<Int>;
        
        // LFO timer steps
        // This calculation is hybrid between fmgen and x68sound.dll, and extend as 20bit fixed dicimal.
        lfo_timerSteps = new Array<Int>();
        for (i in 0...256){
            t = 16 + (i & 15);  // linear interpolation for 4LSBs  
            s = 15 - (i >> 4);  // log-scale shift for 4HSBs  
            lfo_timerSteps[i] = Math.floor((t << (LFO_FIXED_BITS - 4)) * clock_ratio / (8 << s)) >> CLOCK_RATIO_BITS;
        }
        
        lfo_waveTables = new Array<Array<Int>>();  // [0, 255]
        
        // LFO_TABLE_SIZE = 256 cannot be changed !!
        // saw wave
        table = new Array<Int>();
        table2 = new Array<Int>();
        for (i in 0...256){
            table[i] = 255 - i;
            table2[i] = i;
        }
        lfo_waveTables[LFO_WAVE_SAW] = table;
        lfo_waveTables[LFO_WAVE_SAW + 4] = table2;
        
        // pulse wave
        table = new Array<Int>();
        table2 = new Array<Int>();
        for (i in 0...256){
            table[i] = ((i < 128)) ? 255 : 0;
            table2[i] = 255 - table[i];
        }
        lfo_waveTables[LFO_WAVE_SQUARE] = table;
        lfo_waveTables[LFO_WAVE_SQUARE + 4] = table2;
        
        // triangle wave
        table = new Array<Int>();
        table2 = new Array<Int>();
        for (i in 0...64){
            t = i << 1;
            table[i] = t + 128;
            table[127 - i] = t + 128;
            table[128 + i] = 126 - t;
            table[255 - i] = 126 - t;
        }
        for (i in 0...256) {
            table2[i] = 255 - table[i];
        }
        lfo_waveTables[LFO_WAVE_TRIANGLE] = table;
        lfo_waveTables[LFO_WAVE_TRIANGLE + 4] = table2;
        
        // noise wave
        table = new Array<Int>();
        table2 = new Array<Int>();
        for (i in 0...256) {
            table[i] = Math.floor(Math.random() * 255);
            table2[i] = 255 - table[i];
        }
        lfo_waveTables[LFO_WAVE_NOISE] = table;
        lfo_waveTables[LFO_WAVE_NOISE + 4] = table2;
        
        // lfo table for chorus
        table = new Array<Int>();
        for (i in 0...256){
            table[i] = (i - 128) * (i - 128);
        }
        lfo_chorusTables = table;
    }
    
    
    // calculate filter tables
    //--------------------------------------------------
    private function _createFilterTables() : Void
    {
        var i : Int = 0;
        var shift : Float;
        var liner : Float;
        
        filter_cutoffTable = new Array<Float>();
        filter_feedbackTable = new Array<Float>();
        for (i in 0...128){
            filter_cutoffTable[i] = i * i * 0.00006103515625;  //0.00006103515625 = 1/(128*128)  
            filter_feedbackTable[i] = 1.0 + 1.0 / (1.0 - filter_cutoffTable[i]);
        }
        filter_cutoffTable[128] = 1;
        filter_feedbackTable[128] = filter_feedbackTable[128];
        
        // 2.36514 = 3 / ((clock/64)/rate)
        filter_eg_rate = new Array<Int>();
        filter_eg_rate[0] = 0;
        for (i in 0...60){
            shift = (1 << (14 - (i >> 2)));
            liner = ((i & 3) * 0.125 + 0.5);
            filter_eg_rate[i] = Math.floor(2.36514 * shift * liner + 0.5);
        }
        while (i < 64) {
            filter_eg_rate[i] = 1;
            i++;
        }
    }
    
    
    
    
    // calculation
    //--------------------------------------------------
    /** calculate log table index from Number[-1,1].*/
    public static function calcLogTableIndex(n : Float) : Int
    {
        // 369.3299304675746 = 256/log(2)
        // 0.0001220703125 = 1/(2^13)
        if (n < 0) {
            return ((n < -0.0001220703125)) ? (((Math.floor(Math.log(-n) * -369.3299304675746 + 0.5) + 1) << 1) + 1) : LOG_TABLE_BOTTOM;
        }
        else {
            return ((n > 0.0001220703125)) ? ((Math.floor(Math.log(n) * -369.3299304675746 + 0.5) + 1) << 1) : LOG_TABLE_BOTTOM;
        }
    }
    
    
    
    
    // wave tables
    //--------------------------------------------------
    /** @private [internal use] Reset all user tables */
    public function resetAllUserTables() : Void
    {
        // [NOTE] We should free allocated memory area in the environment without garbege collectors.
        var i : Int;
        var pcm : SiOPMWavePCMTable;
        
        // Reset wave tables
        for (i in 0...WAVE_TABLE_MAX){
            if (_customWaveTables[i] != null) {
                _customWaveTables[i].free();
                _customWaveTables[i] = null;
            }
        }
        for (i in 0...PCM_DATA_MAX){
            if (_pcmVoices[i] != null) {
                pcm = try cast(_pcmVoices[i].waveData, SiOPMWavePCMTable) catch(e:Dynamic) null;
                if (pcm != null) pcm._free();
                _pcmVoices[i] = null;
            }
        }

        /*
        for (i=0; i<SAMPLER_TABLE_MAX; i++) { 
        samplerTables[i]_free();
        }
        */  
        
        _stencilCustomWaveTables = null;
        _stencilPCMVoices = null;
    }
    
    
    /** @private [internal use] Register wave table. */
    public function registerWaveTable(index : Int, table : Array<Int>) : SiOPMWaveTable
    {
        // register wave table
        var newWaveTable : SiOPMWaveTable = SiOPMWaveTable.alloc(table);
        index &= WAVE_TABLE_MAX - 1;
        _customWaveTables[index] = newWaveTable;
        
        // update PG_MA3_WAVE waveform 15,23,31.
        if (index < 3) {
            // index=0,1,2 are same as PG_MA3 waveform 15,23,31.
            waveTables[15 + index * 8 + PG_MA3_WAVE] = newWaveTable;
        }
        
        return newWaveTable;
    }
    
    public function registerExistingWaveTable(index : Int, table : SiOPMWaveTable) : SiOPMWaveTable
    {
        // register wave table
        index &= WAVE_TABLE_MAX - 1;
        _customWaveTables[index] = table;

        // update PG_MA3_WAVE waveform 15,23,31.
        if (index < 3) {
            // index=0,1,2 are same as PG_MA3 waveform 15,23,31.
            waveTables[15 + index * 8 + PG_MA3_WAVE] = table;
        }

        return table;

    }

    /** @private [internal use] Register Sampler data. */
    public function registerSamplerData(index : Int, table : Dynamic, ignoreNoteOff : Bool, pan : Int, srcChannelCount : Int, channelCount : Int) : SiOPMWaveSamplerData
    {
        var bank : Int = (index >> NOTE_BITS) & (SAMPLER_TABLE_MAX - 1);
        var sampleData = new SiOPMWaveSamplerData();
        sampleData.initializeFromFloatData(table, ignoreNoteOff, pan, srcChannelCount, channelCount);
        return samplerTables[bank].setSample(sampleData, index & (SAMPLER_DATA_MAX - 1));
    }
    
    
    /** @private [internal use] set global PCM wave table. call from SiONDriver.setPCMWave() */
    public function _setGlobalPCMVoice(index : Int, voice : SiMMLVoice) : SiMMLVoice
    {
        // register PCM data
        index &= PCM_DATA_MAX - 1;
        if (_pcmVoices[index] == null) _pcmVoices[index] = new SiMMLVoice();
        _pcmVoices[index].copyFrom(voice);
        return _pcmVoices[index];
    }
    
    
    /** @private [internal use] get global PCM wave table. call from SiONDriver.setPCMWave() */
    public function _getGlobalPCMVoice(index : Int) : SiMMLVoice
    {
        // register PCM data
        index &= PCM_DATA_MAX - 1;
        if (_pcmVoices[index] == null) {
            _pcmVoices[index] = new SiMMLVoice()._newBlankPCMVoice(index);
        }
        return _pcmVoices[index];
    }
    
    
    /** get wave table from a list of SiONDriver and SiONData */
    public function getWaveTable(index : Int) : SiOPMWaveTable
    {
        if (index < PG_CUSTOM)             return waveTables[index];
        if (index < PG_PCM) {
            index -= PG_CUSTOM;
            if (_stencilCustomWaveTables != null && (_stencilCustomWaveTables[index] != null)) return _stencilCustomWaveTables[index];

            var returnTable = _customWaveTables[index];
            if (returnTable == null) {
                returnTable = noWaveTableOPM;
            }
            return  returnTable;
        }
        return noWaveTable;
    }
    
    
    /** get PCM data from a list of SiONDriver and SiONData */
    public function getPCMData(index : Int) : SiOPMWavePCMTable
    {
        index &= PCM_DATA_MAX - 1;
        if (_stencilPCMVoices != null && _stencilPCMVoices[index] != null) {
            return try cast(_stencilPCMVoices[index].waveData, SiOPMWavePCMTable) catch(e:Dynamic) null;
        }

        return (_pcmVoices[index] == null) ? null : try cast(_pcmVoices[index].waveData, SiOPMWavePCMTable) catch(e:Dynamic) null;
    }
}




