//----------------------------------------------------------------------------------------------------
// SiON Voice data
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.sion;

import openfl.media.Sound;
import org.si.sion.utils.Translator;
import org.si.sion.sequencer.SiMMLVoice;
import org.si.sion.module.ISiOPMWaveInterface;
import org.si.sion.module.SiOPMTable;
import org.si.sion.module.SiOPMChannelParam;
import org.si.sion.module.SiOPMOperatorParam;
import org.si.sion.module.SiOPMWaveTable;
import org.si.sion.module.SiOPMWavePCMData;
import org.si.sion.module.SiOPMWavePCMTable;
import org.si.sion.module.SiOPMWaveSamplerData;
import org.si.sion.module.SiOPMWaveSamplerTable;


/** SiONVoice class provides all of voice setting parameters of SiON.
 *  @see org.si.sion.module.SiOPMChannelParam
 *  @see org.si.sion.module.SiOPMOperatorParam
 */
class SiONVoice extends SiMMLVoice implements ISiOPMWaveInterface
{
    public var param(get, set) : Array<Dynamic>;
    public var paramOPL(get, set) : Array<Dynamic>;
    public var paramOPM(get, set) : Array<Dynamic>;
    public var paramOPN(get, set) : Array<Dynamic>;
    public var paramOPX(get, set) : Array<Dynamic>;
    public var paramMA3(get, set) : Array<Dynamic>;
    public var paramAL(get, set) : Array<Dynamic>;

    // constant
    //--------------------------------------------------
    public static inline var CHIPTYPE_SIOPM : String = "";
    public static inline var CHIPTYPE_OPL : String = "OPL";
    public static inline var CHIPTYPE_OPM : String = "OPM";
    public static inline var CHIPTYPE_OPN : String = "OPN";
    public static inline var CHIPTYPE_OPX : String = "OPX";
    public static inline var CHIPTYPE_MA3 : String = "MA3";
    public static inline var CHIPTYPE_PMS_GUITAR : String = "PMSGuitar";
    public static inline var CHIPTYPE_ANALOG_LIKE : String = "AnalogLike";

    // variables
    //--------------------------------------------------
    /** voice name */
    public var name : String;

    // constrctor
    //--------------------------------------------------
    /** create new SiONVoice instance with '%' parameters, attack rate, release rate and pitchShift.
     *  @param moduleType Module type. 1st argument of '%'.
     *  @param channelNum Channel number. 2nd argument of '%'.
     *  @param ar Attack rate (0-63).
     *  @param rr Release rate (0-63).
     *  @param dt pitchShift (64=1halftone).
     *  @param con connection type of 2nd operator, -1 sets 1operator voice.
     *  @param ws2 wave shape of 2nd operator.
     *  @param dt2 pitchShift of 2nd operator (64=1halftone).
     */
    public function new(moduleType : Int = 5, channelNum : Int = 0, ar : Int = 63, rr : Int = 63, dt : Int = 0, connectionType : Int = -1, ws2 : Int = 0, dt2 : Int = 0)
    {
        super();
        name = "";
        updateTrackParamaters = true;
        
        setModuleType(moduleType, channelNum);
        channelParam.operatorParam[0].ar = ar;
        channelParam.operatorParam[0].rr = rr;
        pitchShift = dt;
        if (connectionType >= 0) {
            channelParam.opeCount = 5;
            channelParam.alg = ((connectionType <= 2)) ? connectionType : 0;
            channelParam.operatorParam[0].setPGType(channelNum);
            channelParam.operatorParam[1].setPGType(ws2);
            channelParam.operatorParam[1].detune = dt2;
        }
    }
    

    // operation
    //--------------------------------------------------
    /** create clone voice. */
    public function clone() : SiONVoice
    {
        var newVoice : SiONVoice = new SiONVoice();
        newVoice.copyFrom(this);
        newVoice.name = name;
        return newVoice;
    }
    

    // FM parameter setter / getter
    //--------------------------------------------------
    /** Set by #&#64; parameters Array */
    private function set_param(args : Array<Dynamic>) : Array<Dynamic>{Translator.setParam(channelParam, args);chipType = "";
        return args;
    }
    
    /** Set by #OPL&#64; parameters Array */
    private function set_paramOPL(args : Array<Dynamic>) : Array<Dynamic>{Translator.setOPLParam(channelParam, args);chipType = "OPL";
        return args;
    }
    
    /** Set by #OPM&#64; parameters Array */
    private function set_paramOPM(args : Array<Dynamic>) : Array<Dynamic>{Translator.setOPMParam(channelParam, args);chipType = "OPM";
        return args;
    }
    
    /** Set by #OPN&#64; parameters Array */
    private function set_paramOPN(args : Array<Dynamic>) : Array<Dynamic>{Translator.setOPNParam(channelParam, args);chipType = "OPN";
        return args;
    }
    
    /** Set by #OPX&#64; parameters Array */
    private function set_paramOPX(args : Array<Dynamic>) : Array<Dynamic>{Translator.setOPXParam(channelParam, args);chipType = "OPX";
        return args;
    }
    
    /** Set by #MA&#64; parameters Array */
    private function set_paramMA3(args : Array<Dynamic>) : Array<Dynamic>{Translator.setMA3Param(channelParam, args);chipType = "MA3";
        return args;
    }
    
    /** Get #AL&#64; parameters by Array */
    private function set_paramAL(args : Array<Dynamic>) : Array<Dynamic>{Translator.setALParam(channelParam, args);chipType = "AnalogLike";
        return args;
    }
    
    
    /** Get #&#64; parameters by Array */
    private function get_param() : Array<Dynamic>{return Translator.getParam(channelParam);
    }
    
    /** Get #OPL&#64; parameters by Array */
    private function get_paramOPL() : Array<Dynamic>{return Translator.getOPLParam(channelParam);
    }
    
    /** Get #OPM&#64; parameters by Array */
    private function get_paramOPM() : Array<Dynamic>{return Translator.getOPMParam(channelParam);
    }
    
    /** Get #OPN&#64; parameters by Array */
    private function get_paramOPN() : Array<Dynamic>{return Translator.getOPNParam(channelParam);
    }
    
    /** Get #OPX&#64; parameters by Array */
    private function get_paramOPX() : Array<Dynamic>{return Translator.getOPXParam(channelParam);
    }
    
    /** Get #MA&#64; parameters by Array */
    private function get_paramMA3() : Array<Dynamic>{return Translator.getMA3Param(channelParam);
    }
    
    /** Get #AL&#64; parameters by Array */
    private function get_paramAL() : Array<Dynamic>{return Translator.getALParam(channelParam);
    }
    
    
    /** get FM voice setting MML.
     *  @param index voice number.
     *  @param type chip type. choose string from SiONVoice.CHIPTYPE_* or null to detect automatically.
     *  @param appendPostfixMML append postfix MML of voice settings.
     *  @return mml string of this voice setting.
     */
    public function getMML(index : Int, type : String = null, appendPostfixMML : Bool = true) : String{
        if (type == null)             type = chipType;
        var mml : String = "";
        switch (type)
        {
            case "OPL":mml = "#OPL@" + Std.string(index) + Translator.mmlOPLParam(channelParam, " ", "\n", name);
            case "OPM":mml = "#OPM@" + Std.string(index) + Translator.mmlOPMParam(channelParam, " ", "\n", name);
            case "OPN":mml = "#OPN@" + Std.string(index) + Translator.mmlOPNParam(channelParam, " ", "\n", name);
            case "OPX":mml = "#OPX@" + Std.string(index) + Translator.mmlOPXParam(channelParam, " ", "\n", name);
            case "MA3":mml = "#MA@" + Std.string(index) + Translator.mmlMA3Param(channelParam, " ", "\n", name);
            case "AnalogLike":mml = "#AL@" + Std.string(index) + Translator.mmlALParam(channelParam, " ", "\n", name);
            default:mml = "#@" + Std.string(index) + Translator.mmlParam(channelParam, " ", "\n", name);
        }
        if (appendPostfixMML) {
            var postfix : String = Translator.mmlVoiceSetting(this);
            if (postfix != "")                 mml += "\n" + postfix;
        }
        return mml + ";";
    }
    
    
    /** set FM voice by MML.
     *  @param mml MML string.
     *  @return voice index number. returns -1 when error.
     */
    public function setByMML(mml : String) : Int{
        // separating
        initialize();
        var rexNum : EReg = new EReg("(#[A-Z]*@)\\s*(\\d+)\\s*{(.*?)}(.*?);", "ms");
        var rexNam : EReg = new EReg("^.*?(//\\s*(.+?))?[\\n\\r]", "gms");
        if (rexNum.match(mml)) {
            var cmd : String = rexNum.matched(1);
            var prm : String = rexNum.matched(3);
            var pfx : String = rexNum.matched(4);
            var voiceIndex : Int = Std.parseInt(rexNum.matched(2));
            switch (cmd)
            {
                case "#@":   {Translator.parseParam(channelParam, prm);chipType = ""; }
                case "#OPL@":{Translator.parseOPLParam(channelParam, prm);chipType = "OPL"; }
                case "#OPM@":{Translator.parseOPMParam(channelParam, prm);chipType = "OPM"; }
                case "#OPN@":{Translator.parseOPNParam(channelParam, prm);chipType = "OPN"; }
                case "#OPX@":{Translator.parseOPXParam(channelParam, prm);chipType = "OPX"; }
                case "#MA@": {Translator.parseMA3Param(channelParam, prm);chipType = "MA3";  }
                case "#AL@": {Translator.parseALParam(channelParam, prm);chipType = "AnalogLike";  }
                default:     return -1;
            }
            Translator.parseVoiceSetting(this, pfx);

            if (rexNam.match(prm) && rexNam.matched(2) != null) {
                name = rexNam.matched(2);
            }
            else {
                name = "";
            }
            return voiceIndex;
        }
        return -1;
    }
    
    
    
    // Voice setter
    //--------------------------------------------------
    /** initializer */
    override public function initialize() : Void
    {
        super.initialize();
        name = "";
        updateTrackParamaters = true;
    }
    
    
    /** Set wave table voice.
     *  @param index wave table number.
     *  @param table wave shape vector ranges in -1 to 1.
     */
    public function setWaveTable(data : Array<Float>) : SiOPMWaveTable
    {
        var i : Int;
        var imax : Int = data.length;
        var table : Array<Int> = new Array<Int>();
        for (i in 0...imax) {
            table[i] = SiOPMTable.calcLogTableIndex(data[i]);
        }
        waveData = SiOPMWaveTable.alloc(table);
        moduleType = 4;
        return try cast(waveData, SiOPMWaveTable) catch(e:Dynamic) null;
    }
    
    
    /** Set as PCM voice (Sound with pitch shift, LPF envlope).
     *  @param data Sound. The Sound instance is extracted internally.
     *  @param samplingNote sampling data's original note
     *  @return PCM data instance as SiOPMWavePCMData
     *  @see org.si.sion.module.SiOPMWavePCMData
     */
    public function setPCMVoice(data : Sound, samplingNote : Int = 69, srcChannelCount : Int = 2, channelCount : Int = 0) : SiOPMWavePCMData
    {
        moduleType = 7;
        var newData = new SiOPMWavePCMData();
        newData.initializeFromSound(data, samplingNote * 64, srcChannelCount, channelCount);
        waveData = newData;
        return newData;
    }
    
    
    /** Set as Sampler voice (Sound without pitch shift, LPF envlope).
     *  @param data wave data, Sound, Vector.&lt;Number&gt; or Vector.&lt;int&gt; is available. The Sound is extracted when the length is shorter than 4[sec].
     *  @param ignoreNoteOff flag to ignore note off
     *  @param channelCount channel count of streaming, 1 for monoral, 2 for stereo.
     *  @return MP3 data instance as SiOPMWaveSamplerData
     *  @see org.si.sion.module.SiOPMWaveSamplerData
     */
    public function setMP3Voice(wave : Sound, ignoreNoteOff : Bool = false, channelCount : Int = 2) : SiOPMWaveSamplerData
    {
        moduleType = 10;
        var newData = new SiOPMWaveSamplerData();
        newData.initializeFromSound(wave, ignoreNoteOff, 0, 2, channelCount);
        waveData = newData;
        return newData;
    }
    
    
    /** Set PCM wave data refered by %7.
     *  @param index PCM data number.
     *  @param data Sound. The Sound instance is extracted internally, the maximum length to extract is SiOPMWavePCMData.maxSampleLengthFromSound[samples].
     *  @param samplingNote Sampling wave's original note number, this allows decimal number
     *  @param keyRangeFrom Assigning key range starts from (not implemented in current version)
     *  @param keyRangeTo Assigning key range ends at (not implemented in current version)
     *  @param srcChannelCount channel count of source data, 1 for monoral, 2 for stereo.
     *  @param channelCount channel count of this data, 1 for monoral, 2 for stereo, 0 sets same with srcChannelCount.
     *  @see #org.si.sion.module.SiOPMWavePCMData.maxSampleLengthFromSound
     *  @see #org.si.sion.SiONDriver.render()
     */
    public function setPCMWave(index : Int, data : Dynamic, samplingNote : Float = 69, keyRangeFrom : Int = 0, keyRangeTo : Int = 127, srcChannelCount : Int = 2, channelCount : Int = 0) : SiOPMWavePCMData
    {
        if (moduleType != 7 || channelNum != index)             waveData = null;
        moduleType = 7;
        channelNum = index;
        var pcmTable : SiOPMWavePCMTable = (try cast(waveData, SiOPMWavePCMTable) catch(e:Dynamic) null);
        if (pcmTable == null) {
            pcmTable =  new SiOPMWavePCMTable();
        }
        var pcmData : SiOPMWavePCMData = new SiOPMWavePCMData();
        pcmData.initializeFromSound(data, Math.floor(samplingNote * 64), srcChannelCount, channelCount);
        pcmTable.setSample(pcmData, keyRangeFrom, keyRangeTo);
        waveData = pcmTable;
        return pcmData;
    }
    
    
    /** Set sampler wave data refered by %10.
     *  @param index note number. 0-127 for bank0, 128-255 for bank1.
     *  @param data Sound. The Sound is extracted when the length is shorter than SiOPMWaveSamplerData.extractThreshold[msec].
     *  @param ignoreNoteOff True to set ignoring note off.
     *  @param pan pan of this sample [-64 - 64].
     *  @param srcChannelCount channel count of source data, 1 for monoral, 2 for stereo.
     *  @param channelCount channel count of this data, 1 for monoral, 2 for stereo, 0 sets same with srcChannelCount.
     *  @return created data instance
     *  @see #org.si.sion.module.SiOPMWaveSamplerData.extractThreshold
     *  @see #org.si.sion.SiONDriver.render()
     */
    public function setSamplerWave(index : Int, data : Dynamic, ignoreNoteOff : Bool = false, pan : Int = 0, srcChannelCount : Int = 2, channelCount : Int = 0) : SiOPMWaveSamplerData
    {
        moduleType = 10;
        var samplerTable : SiOPMWaveSamplerTable = (try cast(waveData, SiOPMWaveSamplerTable) catch(e:Dynamic) null);
        if (samplerTable == null) {
            samplerTable = new SiOPMWaveSamplerTable();
        }
        var sampleData : SiOPMWaveSamplerData = new SiOPMWaveSamplerData();
        sampleData.initializeFromSound(data, ignoreNoteOff, pan, srcChannelCount, channelCount);
        samplerTable.setSample(sampleData, index & (SiOPMTable.NOTE_TABLE_SIZE - 1));
        waveData = samplerTable;
        return sampleData;
    }
    
    
    /** Set sampler table 
     *  @param table sampler table class, ussualy get from SiONSoundFont
     *  @return this instance
     *  @see SiONSoundFont
     */
    public function setSamplerTable(table : SiOPMWaveSamplerTable) : SiONVoice
    {
        moduleType = 10;
        waveData = table;
        return this;
    }
    
    
    /** Set as phisical modeling synth guitar voice.
     *  @param ar attack rate of plunk energy
     *  @param dr decay rate of plunk energy
     *  @param tl total level of plunk energy
     *  @param fixedPitch plunk noise pitch
     *  @param ws wave shape of plunk
     *  @param tension sustain rate of the tone
     *  @return this SiONVoice instance
     */
    public function setPMSGuitar(ar : Int = 48, dr : Int = 48, tl : Int = 0, fixedPitch : Int = 69, ws : Int = 20, tension : Int = 8) : SiONVoice
    {
        moduleType = 11;
        channelNum = 1;
        param = [1, 0, 0, ws, ar, dr, 0, 63, 15, tl, 0, 0, 1, 0, 0, 0, 0, fixedPitch];
        pmsTension = tension;
        chipType = "PMSGuitar";
        return this;
    }
    
    
    /** Set as analog like synth voice.
     *  @param connectionType Connection type, 0=normal, 1=ring, 2=sync, 3=fm.
     *  @param ws1 Wave shape for osc1.
     *  @param ws2 Wave shape for osc2.
     *  @param balance balance between osc1 and 2 (-64 - 64). -64 for only osc1, 0 for same volume, 64 for only osc2.
     *  @param vco2pitch pitch difference in osc1 and 2. 64 for 1 halftone.
     *  @return this SiONVoice instance
     */
    public function setAnalogLike(connectionType : Int, ws1 : Int = 1, ws2 : Int = 1, balance : Int = 0, vco2pitch : Int = 0) : SiONVoice
    {
        channelParam.opeCount = 5;
        channelParam.alg = ((connectionType >= 0 && connectionType <= 3)) ? connectionType : 0;
        channelParam.operatorParam[0].setPGType(ws1);
        channelParam.operatorParam[1].setPGType(ws2);
        
        if (balance > 64)             balance = 64
        else if (balance < -64)             balance = -64;
        
        var tltable : Array<Int> = SiOPMTable.instance.eg_lv2tlTable;
        channelParam.operatorParam[0].tl = tltable[64 - balance];
        channelParam.operatorParam[1].tl = tltable[balance + 64];
        
        channelParam.operatorParam[0].detune = 0;
        channelParam.operatorParam[1].detune = vco2pitch;
        
        chipType = "AnalogLike";
        
        return this;
    }
    
    
    
    
    // Optional settings
    //--------------------------------------------------
    /** Set envelop parameters of all operators.
     *  @param ar Attack rate (0-63).
     *  @param dr Decay rate (0-63).
     *  @param sr Sustain rate (0-63).
     *  @param rr Release rate (0-63).
     *  @param sl Sustain level (0-15).
     *  @param tl Total level (0-127).
     */
    public function setEnvelop(ar : Int, dr : Int, sr : Int, rr : Int, sl : Int, tl : Int) : SiONVoice
    {
        for (i in 0...4){
            var opp : SiOPMOperatorParam = channelParam.operatorParam[i];
            opp.ar = ar;
            opp.dr = dr;
            opp.sr = sr;
            opp.rr = rr;
            opp.sl = sl;
            opp.tl = tl;
        }
        return this;
    }
    
    
    /** Set filter envelop parameters.
     *  @param filterType filter type (0:Low-pass, 1:Band-pass, 2:High-pass)
     *  @param cutoff filter cutoff (0-128)
     *  @param resonance filter resonance (0-9)
     *  @param far filter attack rate (0-63)
     *  @param fdr1 filter decay rate 1 (0-63)
     *  @param fdr2 filter decay rate 2 (0-63)
     *  @param frr filter release rate (0-63)
     *  @param fdc1 filter decay cutoff 1 (0-128)
     *  @param fdc2 filter decay cutoff 2 (0-128)
     *  @param fsc filter sustain cutoff (0-128)
     *  @param frc filter release cutoff (0-128)
     *  @return this SiONVoice instance
     */
    public function setFilterEnvelop(filterType : Int = 0, cutoff : Int = 128, resonance : Int = 0, far : Int = 0, fdr1 : Int = 0, fdr2 : Int = 0, frr : Int = 0, fdc1 : Int = 128, fdc2 : Int = 64, fsc : Int = 32, frc : Int = 128) : SiONVoice
    {
        channelParam.filterType = filterType;
        channelParam.cutoff = cutoff;
        channelParam.resonance = resonance;
        channelParam.far = far;
        channelParam.fdr1 = fdr1;
        channelParam.fdr2 = fdr2;
        channelParam.frr = frr;
        channelParam.fdc1 = fdc1;
        channelParam.fdc2 = fdc2;
        channelParam.fsc = fsc;
        channelParam.frc = frc;
        return this;
    }
    
    
    /** [Pleas use setFilterEnvelop() instead of this function]. Set low pass filter envelop parameters. This function is for compatibility of old versions.
     *  @param cutoff LP filter cutoff (0-128)
     *  @param resonance LP filter resonance (0-9)
     *  @param far LP filter attack rate (0-63)
     *  @param fdr1 LP filter decay rate 1 (0-63)
     *  @param fdr2 LP filter decay rate 2 (0-63)
     *  @param frr LP filter release rate (0-63)
     *  @param fdc1 LP filter decay cutoff 1 (0-128)
     *  @param fdc2 LP filter decay cutoff 2 (0-128)
     *  @param fsc LP filter sustain cutoff (0-128)
     *  @param frc LP filter release cutoff (0-128)
     *  @return this SiONVoice instance
     *  @see setFilterEnvelop()
     */
    public function setLPFEnvelop(cutoff : Int = 128, resonance : Int = 0, far : Int = 0, fdr1 : Int = 0, fdr2 : Int = 0, frr : Int = 0, fdc1 : Int = 128, fdc2 : Int = 64, fsc : Int = 32, frc : Int = 128) : SiONVoice
    {
        return setFilterEnvelop(0, cutoff, resonance, far, fdr1, fdr2, frr, fdc1, fdc2, fsc, frc);
    }
    
    
    /** Set amplitude modulation parameters (same as "ma" command of MML).
     *  @param depth start modulation depth (same as 1st argument)
     *  @param end_depth end modulation depth (same as 2nd argument)
     *  @param delay changing delay (same as 3rd argument)
     *  @param term changing term (same as 4th argument)
     *  @return this instance
     */
    public function setAmplitudeModulation(depth : Int = 0, end_depth : Int = 0, delay : Int = 0, term : Int = 0) : SiONVoice
    {
        channelParam.amd = amDepth = depth;
        amDepthEnd = end_depth;
        amDelay = delay;
        amTerm = term;
        return this;
    }
    
    
    /** Set amplitude modulation parameters (same as "mp" command of MML).
     *  @param depth start modulation depth (same as 1st argument)
     *  @param end_depth end modulation depth (same as 2nd argument)
     *  @param delay changing delay (same as 3rd argument)
     *  @param term changing term (same as 4th argument)
     *  @return this instance
     */
    public function setPitchModulation(depth : Int = 0, end_depth : Int = 0, delay : Int = 0, term : Int = 0) : SiONVoice
    {
        channelParam.pmd = pmDepth = depth;
        pmDepthEnd = end_depth;
        pmDelay = delay;
        pmTerm = term;
        return this;
    }
}



