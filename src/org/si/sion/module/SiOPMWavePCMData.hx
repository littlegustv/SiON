//----------------------------------------------------------------------------------------------------
// class for SiOPM PCM data
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.sion.module;

#if flash
import flash.errors.Error;
import flash.media.Sound;
#else
import openfl.errors.Error;
import openfl.media.Sound;
//import openfl._v2.media.Sound;
#end

import org.si.sion.utils.SiONUtil;
import org.si.sion.sequencer.SiMMLTable;
import org.si.sion.module.SiOPMTable;


/** PCM data class */
class SiOPMWavePCMData extends SiOPMWaveBase
{
    public var sampleCount(get, never) : Int;
    public var samplingOctave(get, never) : Int;
    public var startPoint(get, never) : Int;
    public var endPoint(get, never) : Int;
    public var loopPoint(get, never) : Int;

    // variables
    //----------------------------------------
    /** maximum sampling length when converted from Sound instance */
    public static var maxSampleLengthFromSound : Int = 1048576;
    
    /** wave data */
    public var wavelet : Array<Int>;
    /** channel count */
    public var channelCount : Int;
    
    /** sampling pitch (noteNumber*64) */
    public var samplingPitch : Int;
    
    /** wave starting position in sample count. */
    private var _startPoint : Int;
    /** wave end position in sample count. */
    private var _endPoint : Int;
    /** wave looping position in sample count. -1 means no repeat. */
    private var _loopPoint : Int;
    /** flag to slice after loading */
    private var _sliceAfterLoading : Bool;
    
    // sin table
    private static var _sin : Array<Float> = new Array<Float>();
    
    
    // properties
    //----------------------------------------
    /** Sampling data's length */
    private function get_sampleCount() : Int {
        return ((wavelet != null)) ? (wavelet.length >> (channelCount - 1)) : 0;
    }
    
    /** Sampling data's octave */
    private function get_samplingOctave() : Int{
        return Math.floor(samplingPitch * 0.001272264631043257);
    }
    
    /** wave starting position in sample count. you can set this property by slice(). @see #slice() */
    private function get_startPoint() : Int{
        return _startPoint;
    }
    
    /** wave end position in sample count. you can set this property by slice(). @see #slice() */
    private function get_endPoint() : Int{
        return _endPoint;
    }
    
    /** wave looping position in sample count. -1 means no repeat. you can set this property by slice(). @see #slice() */
    private function get_loopPoint() : Int{
        return _loopPoint;
    }
    

    // constructor
    //----------------------------------------
    /** Constructor. Must call an initialize function after creation.
     */
    public function new()
    {
        super(SiMMLTable.MT_PCM);
    }


    // operations
    //----------------------------------------
    /** Initializer.
     *  @param data wave data from a Sound. The Sound instance is extracted internally.
     *  @param samplingPitch sampling data's original note
     *  @param srcChannelCount channel count of source data, this argument is only available when data type is Vector.&lt;Number&gt;.
     *  @param channelCount channel count of this data, 0 sets same with srcChannelCount
     *  @return this instance.
     */
    public function initializeFromSound(data : Sound, samplingPitch : Int = 4416, srcChannelCount : Int = 2, channelCount : Int = 0) : SiOPMWavePCMData
    {
        _sliceAfterLoading = false;
        srcChannelCount = ((srcChannelCount == 1)) ? 1 : 2;
        if (channelCount == 0)             channelCount = srcChannelCount;
        this.channelCount = ((channelCount == 1)) ? 1 : 2;
        _listenSoundLoadingEvents(data);
        this.samplingPitch = samplingPitch;

        _startPoint = 0;
        _endPoint = this.sampleCount - 1;
        _loopPoint = -1;
        return this;
    }

    /** Initializer.
     *  @param data wave data, Array&lt;int&gt; is available.
     *  @param samplingPitch sampling data's original note
     *  @param srcChannelCount channel count of source data, this argument is only available when data type is Vector.&lt;Number&gt;.
     *  @param channelCount channel count of this data, 0 sets same with srcChannelCount
     *  @return this instance.
     */
    public function initializeFromIntData(data : Array<Int>, samplingPitch : Int = 4416, srcChannelCount : Int = 2, channelCount : Int = 0) : SiOPMWavePCMData
    {
        _sliceAfterLoading = false;
        srcChannelCount = ((srcChannelCount == 1)) ? 1 : 2;
        if (channelCount == 0)             channelCount = srcChannelCount;
        this.channelCount = ((channelCount == 1)) ? 1 : 2;
        wavelet = data;
        this.samplingPitch = samplingPitch;

        _startPoint = 0;
        _endPoint = this.sampleCount - 1;
        _loopPoint = -1;
        return this;
    }

    /** Initializer.
     *  @param data wave data, Array&lt;Number&gt;
     *  @param samplingPitch sampling data's original note
     *  @param srcChannelCount channel count of source data, this argument is only available when data type is Vector.&lt;Number&gt;.
     *  @param channelCount channel count of this data, 0 sets same with srcChannelCount
     *  @return this instance.
     */
    public function initializeFromFloatData(data : Array<Float>, samplingPitch : Int = 4416, srcChannelCount : Int = 2, channelCount : Int = 0) : SiOPMWavePCMData
    {
        _sliceAfterLoading = false;
        srcChannelCount = ((srcChannelCount == 1)) ? 1 : 2;
        if (channelCount == 0)             channelCount = srcChannelCount;
        this.channelCount = ((channelCount == 1)) ? 1 : 2;
        wavelet = SiONUtil.logTransVector(data, srcChannelCount, null, this.channelCount);
        this.samplingPitch = samplingPitch;

        _startPoint = 0;
        _endPoint = this.sampleCount - 1;
        _loopPoint = -1;
        return this;
    }

    /** Slicer setting. You can cut samples and set repeating.
     *  @param startPoint slicing point to start data. The negative value skips head silence.
     *  @param endPoint slicing point to end data, The negative value calculates from the end.
     *  @param loopPoint slicing point to repeat data, -1 sets no repeat, other negative value sets loop tail samples
     *  @return this instance.
     */
    public function slice(startPoint : Int = -1, endPoint : Int = -1, loopPoint : Int = -1) : SiOPMWavePCMData
    {
        _startPoint = startPoint;
        _endPoint = endPoint;
        _loopPoint = loopPoint;
        if (!_isSoundLoading)             _slice()
        else _sliceAfterLoading = true;
        return this;
    }
    
    
    /** Get initial sample index. 
     *  @param phase Starting phase, ratio from start point to end point(0-1).
     */
    public function getInitialSampleIndex(phase : Float = 0) : Int
    {
        return Math.floor(_startPoint * (1 - phase) + _endPoint * phase);
    }
    
    
    /** Loop tail samples, this function updates endPoint and loopPoint. This function is called from slice() when loopPoint &lt; -1.
     *  @param sampleCount looping sample count.
     *  @param tailMargin margin for end point. sample count from tail of wave data (consider mp3's end gap).
     *  @param crossFade using short cross fading to reduce sample step noise while looping.
     *  @see #slice()
     */
    public function loopTailSamples(sampleCount : Int = 2205, tailMargin : Int = 0, crossFade : Bool = true) : SiOPMWavePCMData
    {
        _endPoint = _seekEndGap() - tailMargin;
        if (_endPoint < _startPoint + sampleCount) {
            if (_endPoint < _startPoint)                 _endPoint = _startPoint;
            _loopPoint = _startPoint;
            return this;
        }
        _loopPoint = _endPoint - sampleCount;
        
        if (crossFade && _loopPoint > _startPoint + sampleCount) {
            var i : Int;
            var j : Int;
            var t : Float;
            var idx0 : Int;
            var idx1 : Int;
            var li0 : Int;
            var li1 : Int;
            var log : Array<Int> = SiOPMTable.instance.logTable;
            var envtop : Int = (-SiOPMTable.ENV_TOP) << 3;
            var i2n : Float = 1 / (1 << SiOPMTable.LOG_VOLUME_BITS);
            var offset : Int = _loopPoint << (channelCount - 1);
            var imax : Int = sampleCount << (channelCount - 1);
            var dt : Float = 1.5707963267948965 / imax;
            if (_sin.length != imax) {
                _sin[imax-1] = 0.0;
                i = 0;
                t = 0;
                while (i < imax) {
                    _sin[i] = Math.sin(t);
                    i++;
                    t += dt;
                }
            }
            for (i in 0...imax){
                idx0 = offset + i;
                idx1 = idx0 - imax;
                li0 = wavelet[idx0] + envtop;
                li1 = wavelet[idx1] + envtop;
                j = imax - 1 - i;
                wavelet[idx0] = SiOPMTable.calcLogTableIndex((log[li0] * _sin[j] + log[li1] * _sin[i]) * i2n);
            }
        }
        
        return this;
    }
    
    
    // seek mp3 head gap
    private function _seekHeadSilence() : Int
    {
        var i : Int = 0;
        var imax : Int = wavelet.length;
        var threshold : Int = SiOPMTable.LOG_TABLE_BOTTOM - SiOPMTable.LOG_TABLE_RESOLUTION * 14;  // 1/128  
        i = 0;
        while (i < imax) {
            if (wavelet[i] < threshold) {
                break;
            }
            i++;
        }
        return i >> (channelCount - 1);
    }
    
    
    // seek mp3 end gap
    private function _seekEndGap() : Int
    {
        var i : Int;
        var threshold : Int = SiOPMTable.LOG_TABLE_BOTTOM - SiOPMTable.LOG_TABLE_RESOLUTION * 2;  // 1/4096  
        i = wavelet.length - 1;
        while (i > 0) {
            if (wavelet[i] < threshold) {
                break;
            }
            --i;
        }
        return (i >> (channelCount - 1)) - 100;
    }
    
    
    /** @private */
    override private function _onSoundLoadingComplete(sound : Sound) : Void
    {
        wavelet = SiONUtil.logTrans(sound, null, channelCount, maxSampleLengthFromSound);
        if (_sliceAfterLoading) {
            _slice();
        }
        _sliceAfterLoading = false;
    }
    
    
    private function _slice() : Void
    {
        // start point
        if (_startPoint < 0)             _startPoint = _seekHeadSilence();
        if (_loopPoint < -1) {
            // set loop infinitly
            if (_endPoint >= 0) {
                loopTailSamples(-_loopPoint);
                if (_startPoint >= _endPoint)                     _endPoint = _startPoint;
            }
            else {
                loopTailSamples(-_loopPoint, -_endPoint);
            }
        }
        else {
            // end point
            var waveletLengh : Int = sampleCount;
            if (_endPoint < 0)                 _endPoint = _seekEndGap() + _endPoint
            else if (_endPoint < _startPoint)                 _endPoint = _startPoint
            // loop point
            else if (waveletLengh < _endPoint)                 _endPoint = waveletLengh - 1;
            
            if (_loopPoint != -1 && _loopPoint < _startPoint)                 _loopPoint = _startPoint
            else if (_endPoint < _loopPoint)                 _loopPoint = -1;
        }
    }
}


