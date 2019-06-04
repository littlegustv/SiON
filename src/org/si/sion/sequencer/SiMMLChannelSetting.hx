//----------------------------------------------------------------------------------------------------
// class for SiMML sequencer setting
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.sion.sequencer;

import org.si.sion.sequencer.base.MMLSequence;
import org.si.sion.module.SiOPMModule;
import org.si.sion.module.SiOPMWavePCMTable;
import org.si.sion.module.SiOPMTable;
import org.si.sion.module.SiOPMChannelParam;
import org.si.sion.module.channels.SiOPMChannelManager;
import org.si.sion.module.channels.SiOPMChannelBase;



/** @private SiOPM channel setting */
class SiMMLChannelSetting
{
    // constants
    //--------------------------------------------------
    public static inline var SELECT_TONE_NOP : Int = 0;
    public static inline var SELECT_TONE_NORMAL : Int = 1;
    public static inline var SELECT_TONE_FM : Int = 2;
    
    
    
    
    // variables
    //--------------------------------------------------
    public var type : Int;
    @:allow(org.si.sion.sequencer)
    private var _selectToneType : Int;
    @:allow(org.si.sion.sequencer)
    private var _pgTypeList : Array<Int>;
    @:allow(org.si.sion.sequencer)
    private var _ptTypeList : Array<Int>;
    @:allow(org.si.sion.sequencer)
    private var _initVoiceIndex : Int;
    @:allow(org.si.sion.sequencer)
    private var _voiceIndexTable : Array<Int>;
    @:allow(org.si.sion.sequencer)
    private var _channelType : Int;
    @:allow(org.si.sion.sequencer)
    private var _isSuitableForFMVoice : Bool;
    @:allow(org.si.sion.sequencer)
    private var _defaultOpeCount : Int;
    private var _table : SiOPMTable;
    
    
    
    
    // constructor
    //--------------------------------------------------
    public function new(type : Int, offset : Int, length : Int, step : Int, channelCount : Int)
    {
        var i : Int;
        var idx : Int;
        _table = SiOPMTable.instance;
        _pgTypeList = new Array<Int>();
        _ptTypeList = new Array<Int>();
        i = 0;
        idx = offset;
        while (i < length){
            _pgTypeList[i] = idx;
            _ptTypeList[i] = _table.getWaveTable(idx).defaultPTType;
            i++;
            idx += step;
        }
        _voiceIndexTable = new Array<Int>();
        for (i in 0...channelCount){
            _voiceIndexTable[i] = i;
        }
        
        this._initVoiceIndex = 0;
        this.type = type;
        _channelType = SiOPMChannelManager.CT_CHANNEL_FM;
        _selectToneType = SELECT_TONE_NORMAL;
        _defaultOpeCount = 1;
        _isSuitableForFMVoice = true;
    }
    
    
    
    
    // tone setting
    //--------------------------------------------------
    /** initialize tone by channel number. 
     *  call from SiMMLTrack::reset()/setChannelModuleType().
     *  call from "%" MML command
     */
    @:allow(org.si.sion.sequencer)
    private function initializeTone(track : SiMMLTrack, chNum : Int, bufferIndex : Int) : Int
    {
        // update channel instance
        if (track.channel == null) {
            // create new channel
            track.channel = SiOPMChannelManager.newChannel(_channelType, null, bufferIndex);
        }
        else if (track.channel.channelType != _channelType) {
            // change channel type
            var prev : SiOPMChannelBase = track.channel;
            track.channel = SiOPMChannelManager.newChannel(_channelType, prev, bufferIndex);
            SiOPMChannelManager.deleteChannel(prev);
        }
        else {
            // initialize channel
            track.channel.initialize(track.channel, bufferIndex);
            track._resetVolumeOffset();
        }  // voiceIndex = chNum except for PSG, APU and analog    // initialize  

        var voiceIndex : Int = _initVoiceIndex;
        var chNumRestrict : Int = chNum;
        if (0 <= chNum && chNum < _voiceIndexTable.length) voiceIndex = _voiceIndexTable[chNum]
        else chNumRestrict = 0;
        // track has channel number include -1.
        track._channelNumber = ((chNum < 0)) ? -1 : chNum;
        // channel requires restrticted channel number
        track.channel.setChannelNumber(chNumRestrict);
        track.channel.setAlgorism(_defaultOpeCount, 0);
        selectTone(track, voiceIndex);

        // return voice index
        return (chNum == -1) ? -1 : voiceIndex;
    }
    
    
    /** select tone by tone number. 
     *  call from initializeTone(), SiMMLTrack::setChannelModuleType()/_bufferEnvelop()/_keyOn()/_setChannelParameters().
     *  call from "%" and "&#64;" MML command
     */
    @:allow(org.si.sion.sequencer)
    private function selectTone(track : SiMMLTrack, voiceIndex : Int) : MMLSequence
    {
        if (voiceIndex == -1) return null;
        
        var voice : SiMMLVoice;
        
        switch (_selectToneType)
        {
            case SELECT_TONE_NORMAL:
                if (voiceIndex < 0 || voiceIndex >= _pgTypeList.length)                     voiceIndex = _initVoiceIndex;
                track.channel.setType(_pgTypeList[voiceIndex], _ptTypeList[voiceIndex]);
            case SELECT_TONE_FM:  // %6  
                if (voiceIndex < 0 || voiceIndex >= SiMMLTable.VOICE_MAX)                     voiceIndex = 0;
                voice = SiMMLTable.instance.getSiMMLVoice(voiceIndex);
                if (voice != null) {
                    if (voice.updateTrackParamaters) {
                        voice.updateTrackVoice(track);
                        return null;
                    }
                    else {
                        // this module changes only channel params, not track params.
                        track.channel.setSiOPMChannelParam(voice.channelParam, false, false);
                        track._resetVolumeOffset();
                        return ((voice.channelParam.initSequence.isEmpty())) ? null : voice.channelParam.initSequence;
                    }
                }
        }
        return null;
    }
}


