//----------------------------------------------------------------------------------------------------
// Basic class of a drivers between MMLEvent and sound module.
//  Copyright (c) 2008 keim All rights reserved.
//  Distributed under BSD-style license (see org.si.license.txt).
//----------------------------------------------------------------------------------------------------

package org.si.sion.sequencer.base;

import openfl.errors.Error;



/**
 *  MMLSequencer is the basic class of a bridges between MMLEvents, sound modules and sound systems. 
 *  You should follow this in your inherited classes. <br/>
 *  1) Register MML event listeners by setMMLEventListener() or newMMLEventListener().<br/>
 *  2) Override on...() functions.<br/>
 *  3) Override prepareCompile() and compile() if necessary.<br/>
 *  4) Override prepareProcess() and process() to process audio data.<br/>
 *  And usage is as below. 
 *  1) Call initialize() to initialize.<br/>
 *  2) Call prepareCompile() and compile() to compile the MML string to MMLData.<br/>
 *  3) Call prepareProcess() and process() to process audio in inherited class.<br/>
 */
class MMLSequencer
{
    public var bpm(get, set) : Float;

    // namespace
    //--------------------------------------------------
    
    
    
    
    
    // constant
    //--------------------------------------------------
    /** bits for fixed decimal */
    @:allow(org.si.sion.sequencer.base)
    private static inline var FIXED_BITS : Int = 8;
    /** filter for decimal fraction area */
    @:allow(org.si.sion.sequencer.base)
    private static var FIXED_FILTER : Int = (1 << FIXED_BITS) - 1;
    
    
    
    
    // variables
    //--------------------------------------------------
    /** MML parser setting.  */
    public var setting : MMLParserSetting;
    /** Audio setting, sampling ratio. The value is restricted as 22050 or 44100.  */
    public var sampleRate : Int;
    
    /** @private Global sequence executor */
    private var globalExecutor : MMLExecutor;
    /** @private Current processing sequence executor. You can refer this in onProcess. */
    private var currentExecutor : MMLExecutor;
    /** @private Current MMLData to compile or process */
    private var mmlData : MMLData;
    /** @private changable beat per minutes */
    private var _changableBPM : BeatPerMinutes;
    /** @private beat per minutes */
    private var _bpm : BeatPerMinutes;
    
    /** @private buffer index for global sequence */
    private var _globalBufferIndex : Int;
    /** @private beat counter in 16th */
    private var _globalBeat16 : Float;
    /** @private filter for onBeat() callback. 0=16th beat, 1=8th beat, 3=4th beat, 7=2nd beat, 15=whole tone ...*/
    private var _onBeatCallbackFilter : Int;
    
    /** @private [sion sequencer internal] abstruct global sequence. */
    public static var _tempExecutor : MMLExecutor = new MMLExecutor();
    
    
    private var _newUserDefinedEventID : Int = MMLEvent.USER_DEFINE;  // id value of new user-defined event.  
    private var _userDefinedEventID : Map<String, Int> = new Map<String, Int>();  // id map of user-defined event letter set by newMMLEventListener().
    private var _eventCommandLetter : Array<Dynamic> = [];  // event commands  
    private var _eventHandlers : Array<MMLEvent->MMLEvent> = new Array<MMLEvent->MMLEvent>();  // list of event handler functions set by setMMLEventListener().
    private var _eventGlobalFlags : Array<Bool> = new Array<Bool>();  // global event flag  
    
    private var _processSampleCount : Int;  // leftover of buffer sample count in processing  
    private var _globalBufferSampleCount : Int;  // leftover of buffer sample count in global sequence  
    private var _globalExecuteSampleCount : Int;  // executing buffer length in global sequence  
    
    private var _bufferLength : Int;  // buffering length  
    
    
    
    // properties
    //--------------------------------------------------
    /** @private [sion internal] beat per minute. refer from SiONDriver.bpm */
    private function get_bpm() : Float{
        return _changableBPM.bpm;
    }
    /** @private */
    private function set_bpm(newValue : Float) : Float{
        var oldValue : Float = _changableBPM.bpm;
        if (_changableBPM.update(newValue, sampleRate)) {
            onTempoChanged(oldValue / newValue);
        }
        return newValue;
    }
    
    
    
    
    // constructor
    //--------------------------------------------------
    /** Default constructor initializes event handlers. */
    public function new()
    {
        this.setting = new MMLParserSetting();
        
        for (i in 0...MMLEvent.COMMAND_MAX) {
            _eventHandlers[i] = _nop;
        }
        setMMLEventListener(MMLEvent.NOP, _default_onNoOperation, false);
        setMMLEventListener(MMLEvent.PROCESS, _default_onProcess, false);
        setMMLEventListener(MMLEvent.REPEAT_ALL, _default_onRepeatAll, false);
        setMMLEventListener(MMLEvent.REPEAT_BEGIN, _default_onRepeatBegin, false);
        setMMLEventListener(MMLEvent.REPEAT_BREAK, _default_onRepeatBreak, false);
        setMMLEventListener(MMLEvent.REPEAT_END, _default_onRepeatEnd, false);
        setMMLEventListener(MMLEvent.SEQUENCE_TAIL, _default_onSequenceTail, false);
        setMMLEventListener(MMLEvent.GLOBAL_WAIT, _default_onGlobalWait, true);
        setMMLEventListener(MMLEvent.TEMPO, _default_onTempo, true);
        setMMLEventListener(MMLEvent.TIMER, _default_onTimer, true);
        setMMLEventListener(MMLEvent.INTERNAL_WAIT, _default_onInternalWait, false);
        setMMLEventListener(MMLEvent.INTERNAL_CALL, _default_onInternalCall, false);
        setMMLEventListener(MMLEvent.TABLE_EVENT, _nop, true);
        _newUserDefinedEventID = MMLEvent.USER_DEFINE;
        
        _changableBPM = new BeatPerMinutes(120, 44100);
        _bpm = _changableBPM;
        globalExecutor = new MMLExecutor();
        MMLParser._getCommandLetters(_eventCommandLetter);
        
        // 3 : callback every 4 beat
        _onBeatCallbackFilter = 3;
    }
    
    
    
    
    // internal operation
    //--------------------------------------------------
    /** Similar with an addEventListener(), but only one listener can be set for one event.
     *  @param id The ID of the event.
     *  @param func The functor of the event called back when its processing.
     */
    private function setMMLEventListener(id : Int, func : MMLEvent->MMLEvent, isGlobal : Bool = false) : Void
    {
        _eventHandlers[id] = func;
        _eventGlobalFlags[id] = isGlobal;
    }
    
    
    /** Register new MMLEvent letter.
     *  @param letter The letter of the event on mml.
     *  @param func The functor of the event called back when its processing.
     *  @return The ID of the event. This value is greater than or equal to MMLEvent.USER_DEFINE.
     */
    public function newMMLEventListener(letter : String, func : MMLEvent->MMLEvent, isGlobal : Bool = false) : Int
    {
        var id : Int = _newUserDefinedEventID++;
        _userDefinedEventID.set(letter, id);
        _eventCommandLetter[id] = letter;
        _eventHandlers[id] = func;
        _eventGlobalFlags[id] = isGlobal;
        return id;
    }
    
    
    /** Get MMLEvent id by mml command letter. 
     *  @param mmlCommand letter of MML command.
     *  @return Event id. Returns 0 if not found.
     */
    public function getEventID(mmlCommand : String) : Int
    {
        var id : Int = MMLParser.getEventID(mmlCommand);
        if (id != 0)             return id;
        if (_userDefinedEventID.exists(mmlCommand)) return _userDefinedEventID.get(mmlCommand);
        return 0;
    }
    
    
    /** Get MML command letters by event id.
     *  @param eventID Event id.
     *  @return letter of MML command. Returns null if not found.
     */
    public function getEventLetter(eventID : Int) : String
    {
        return _eventCommandLetter[eventID];
    }
    
    
    
    
    // compile
    //--------------------------------------------------
    /** Prepare to compile mml string. Calls onBeforeCompile() inside.
     *  @param data Data instance.
     *  @param mml MML String.
     *  @return Returns false when it's not necessary to compile.
     */
    public function prepareCompile(data : MMLData, mml : String) : Bool
    {
        trace("MMLSequencer.prepareCompile()");
        // set internal parameters
        mmlData = data;
        if (mmlData == null) return false;

        trace('Clearing');
        // clear mml data
        mmlData.clear();

        trace('Setting. MMLParser is $MMLParser');
        // setting
        MMLParser._setUserDefinedEventID(_userDefinedEventID);
        MMLParser._setGlobalEventFlags(_eventGlobalFlags);

        trace('MMLS: 2');

        // callback before compiling
        var mmlString : String = onBeforeCompile(mml);
        trace('MMLS: 2.5');
        if (mmlString == null) {
            mmlData = null;
            return false;
        }

        trace('MMLS: 3');
        // prepare
        MMLParser.prepareParse(setting, mmlString);
        trace('MMLS: 4');
        return true;
    }
    
    
    /** Parse mml string. Calls onAfterCompile() inside.
     *  @param interval Interval to interrupt parsing [ms]. Set 0 to parse at once.
     *  @return Return compile progression. Returns 1 when its finished, or when preparation has not completed.
     */
    public function compile(interval : Int = 1000) : Float
    {
        if (mmlData == null) return 1;

        // parse mmlString
        var e : MMLEvent = MMLParser.parse(interval);
        // null means parse incomplete.
        if (e == null) return MMLParser.parseProgress;

        // create main sequence group
        mmlData.sequenceGroup.alloc(e);
        // abstruct global sequences
        _abstructGlobalSequence();
        // callback after parsing
        onAfterCompile(mmlData.sequenceGroup);
        
        return 1;
    }
    
    
    
    
    // process
    //--------------------------------------------------
    /** @private [sion internal] Prepare to process audio. Override and call this in the overrided function.
     *  @param bufferLength Sample count to buffer samples at once.
     *  @param sampleRate Sampling rate. 44100 or 22050 is available.
     *  @param resetParams Reset all channel parameters.
     */
    public function _prepareProcess(data : MMLData, sampleRate : Int, bufferLength : Int) : Void
    {
        if (sampleRate != 22050 && sampleRate != 44100) {
            throw new Error("MMLSequencer error: Only 22050 or 44100 sampling rate is available.");
        }
        mmlData = data;
        this.sampleRate = sampleRate;
        _bufferLength = bufferLength;
        if (mmlData != null && mmlData._initialBPM != null) {
            _changableBPM.update(mmlData._initialBPM.bpm, sampleRate);
            globalExecutor.initialize(mmlData.globalSequence);
        }
        else {
            _changableBPM.update(setting.defaultBPM, sampleRate);
            globalExecutor.initialize(null);
        }
        _bpm = _changableBPM;
        _globalBufferIndex = 0;
        _globalBeat16 = 0;
    }
    
    
    /** @private [sion internal] Process all tracks. override this function. 
     *  @return Returns true when all processes are finished.
     */
    public function _process() : Void
    {
        // DO NOTHING !!
        // You dont have to call this in your overrided function.
        
    }
    
    
    /** Set global sequence. This function must be called after prepareProcess() and before process(). */
    public function setGlobalSequence(seq : MMLSequence) : Void
    {
        globalExecutor.initialize(seq);
    }
    
    /** start global sequence. */
    private function startGlobalSequence() : Void
    {
        _globalBufferSampleCount = _bufferLength;
        _globalExecuteSampleCount = 0;
        _globalBufferIndex = 0;
    }

    /** execute global sequence. returns executing sample length. */
    private function executeGlobalSequence() : Int
    {
        currentExecutor = globalExecutor;
        
        var event : MMLEvent = currentExecutor.pointer;
        _globalExecuteSampleCount = 0;
        do{
            if (event == null) {
                _globalExecuteSampleCount = _globalBufferSampleCount;
                _globalBufferSampleCount = 0;
            }
            else {
                // update _globalExecuteSampleCount in some _eventHandler()s
                event = _eventHandlers[event.id](event);
                currentExecutor.pointer = event;
            }
        } while (_globalExecuteSampleCount == 0);
        return _globalExecuteSampleCount;
    }

    /** check global sequences pointer acheives to the end. */
    private function isEndGlobalSequence() : Bool
    {
        var prevBeat : Float = _globalBeat16;
        var floorPrevBeat : Int = Math.floor(prevBeat);
        _globalBufferIndex += _globalExecuteSampleCount;
        _globalBeat16 += _globalExecuteSampleCount * _bpm.beat16PerSample;
        var floorCurrBeat : Int = Math.floor(_globalBeat16);
        if (prevBeat == 0) {
            onBeat(0, 0);
        }
        else {
            while (floorPrevBeat < floorCurrBeat) {
                floorPrevBeat++;
                if ((floorPrevBeat & _onBeatCallbackFilter) == 0) {
                    onBeat(Math.floor((floorPrevBeat - prevBeat) * _bpm.samplePerBeat16), floorPrevBeat);
                }
            }
        }
        if (_globalBufferSampleCount == 0) {
            _globalBufferIndex = 0;
            return true;
        }
        return false;
    }
    
    
    /** Processing audio by one executor. Calls onProcess() inside.
     *  @param  exe MMLExecutor to process.
     *  @param  bufferSampleCount Buffering length of processing samples at once.
     *  @return Returns true if the sequence already finished.
     */
    private function processMMLExecutor(exe : MMLExecutor, bufferSampleCount : Int) : Bool
    {
        currentExecutor = exe;

        // buffering
        var event : MMLEvent = currentExecutor.pointer;
        _processSampleCount = bufferSampleCount;
        while (_processSampleCount > 0){
            if (event == null) {
                _eventHandlers[MMLEvent.NOP](MMLEvent.nopEvent);
                return true;
            }
            else {
                // update _processSampleCount in some _eventHandler()s
                event = _eventHandlers[event.id](event);
                currentExecutor.pointer = event;
            }
        }
        return false;
    }
    
    
    
    
    // process
    //--------------------------------------------------
    /** @private [protected] Calculate sample count from length of MMLEvent. */
    private function calcSampleCount(len : Int) : Int
    {
        return Math.floor(len * _bpm._samplePerTick) >> FIXED_BITS;
    }
    
    
    /** @private [protected] current position in tick count */
    private function currentTickCount() : Int
    {
        return Math.floor(currentExecutor._currentTickCount - currentExecutor._residueSampleCount * _bpm.tickPerSample);
    }
    
    
    /** @private [protected] Call onTableParse. */
    private function callOnTableParse(prev : MMLEvent) : Void
    {
        var tableEvent : MMLEvent = prev.next;
        onTableParse(prev, MMLParser._getSystemEventString(tableEvent));
        prev.next = tableEvent.next;
        MMLParser._freeEvent(tableEvent);
    }
    
    
    
    
    // virtual functions
    //--------------------------------------------------
    /** Callback before parse. This function is called from parse() before parseing.
     *  @param mml The mml string to parse.
     *  @return The mml string you want to parse. Parses with default mml string when you return null.
     */
    private function onBeforeCompile(mml : String) : String
    {
        trace("onBeforeCompile", mml);
        return null;
    }
    
    
    /** Callback after parse. This function is called from parse() after parseing.
     */
    private function onAfterCompile(seqGroup : MMLSequenceGroup) : Void
    {
        
    }
    
    
    /** Callback when table event was found.
     */
    private function onTableParse(prev : MMLEvent, table : String) : Void
    {
        
    }
    
    
    /** Callback on processing. This function is called from process(). 
     *  @param length Sample length to process calculated from settings.
     *  @param e MMLEvent that calls onProcess().
     */
    private function onProcess(length : Int, e : MMLEvent) : Void
    {
        
    }
    
    
    /** Callback when the tempo is changed.
     *  @param tempoRatio Ratio of changed tempo and previous tempo.
     */
    private function onTempoChanged(tempoRatio : Float) : Void
    {
        
    }
    
    
    /** Callback when streaming interrupted by timer . */
    private function onTimerInterruption() : Void
    {
        
    }
    
    
    /** Callback on every 16th beats. */
    private function onBeat(delaySamples : Int, beatCounter : Int) : Void
    {
        
    }
    
    
    
    private function sortEvents(x : MMLEvent, y : MMLEvent) : Int
    {
        if (x.length == y.length) return 0;

        if (x.length > y.length) return 1;

        return -1;
    }

    // private functions
    //--------------------------------------------------
    private function _abstructGlobalSequence() : Void
    {
        var seqGroup : MMLSequenceGroup = mmlData.sequenceGroup;
        
        var list : Array<MMLEvent> = new Array<MMLEvent>();
        var seq : MMLSequence;
        var prev : MMLEvent;
        var e : MMLEvent;
        var pos : Int;
        var count : Int;
        var hasNoEvent : Bool;
        var i : Int;
        var initialBPM : Int;
        
        seq = seqGroup.headSequence;
        while (seq != null) {
            count = seq.headEvent.data;
            if (count == 0) {
                seq = seq.nextSequence;
                continue;
            }

            // initialize
            _tempExecutor.initialize(seq);
            prev = seq.headEvent;
            e = prev.next;
            pos = 0;
            hasNoEvent = true;
            // calculate position and pickup global events
            while (e != null && (count > 0 || hasNoEvent)) {
                if (_eventGlobalFlags[e.id]) {
                    if (e.id == MMLEvent.TABLE_EVENT) {
                        // table event
                        callOnTableParse(prev);
                    }
                    else {
                        // global event
                        if (seq.headEvent.jump == e)
                            seq.headEvent.jump = prev;
                        prev.next = e.next;
                        e.next = null;
                        e.length = pos;
                        list.push(e);
                    }
                    e = prev.next;
                    count--;
                }
                else if (e.length != 0) {
                    // note or rest
                    pos += e.length;
                    if (e.id != MMLEvent.REST)
                        hasNoEvent = false;
                    prev = e;
                    e = e.next;
                }
                else {
                    // others
                    prev = e;
                    var _sw1_ = (e.id);                    

                    switch (_sw1_)
                    {
                        case MMLEvent.REPEAT_BEGIN:
                            e = _tempExecutor._onRepeatBegin(e);
                        case MMLEvent.REPEAT_BREAK:
                            e = _tempExecutor._onRepeatBreak(e);
                            if (prev.next != e)
                                prev = prev.jump.jump;
                        case MMLEvent.REPEAT_END:
                            e = _tempExecutor._onRepeatEnd(e);
                            if (prev.next != e)
                                prev = prev.jump;
                        case MMLEvent.REPEAT_ALL:
                            e = _tempExecutor._onRepeatAll(e);
                        case MMLEvent.SEQUENCE_TAIL:
                            e = null;
                        default:
                            e = e.next;
                            hasNoEvent = true;
                    }
                }
            }

            // if no event (except rest) in the sequence, skip this sequence
            if (hasNoEvent) {
                //trace("skip sequence");
                seq = seq._removeFromChain();
            }
            seq = seq.nextSequence;
        }

        // sort and create global sequence
        seq = mmlData.globalSequence;
        
        list.sort(sortEvents);
        pos = 0;
        initialBPM = 0;
        for (e in list){
            if (e.length == 0 && e.id == MMLEvent.TEMPO) {
                // first tempo command is default bpm.
                initialBPM = Math.floor(mmlData._calcBPMfromTcommand(Math.floor(e.data)));
            }
            else {
                count = e.length - pos;
                pos = e.length;
                e.length = 0;
                if (count > 0) seq.appendNewEvent(MMLEvent.GLOBAL_WAIT, 0, count);
                seq.push(e);
            }
        }

        //trace(seq);
        // set default bpm in mmlData
        if (initialBPM > 0) {
            mmlData._initialBPM = new BeatPerMinutes(initialBPM, 44100, setting.resolution);
        }
    }
    
    
    
    // default callback functions
    //--------------------------------------------------
    /** Operates nothing. */
    private function _nop(e : MMLEvent) : MMLEvent
    {
        return e.next;
    }
    
    
    /** default operation for MMLEvent.NOP. */
    private function _default_onNoOperation(e : MMLEvent) : MMLEvent
    {
        onProcess(_processSampleCount, e);
        currentExecutor._residueSampleCount -= _processSampleCount;
        return e;
    }
    
    
    /** default operation for MMLEvent.GLOBAL_WAIT. */
    private function _default_onGlobalWait(e : MMLEvent) : MMLEvent
    {
        var exec : MMLExecutor = currentExecutor;
        
        // set processing length
        if (exec._residueSampleCount == 0) {
            var sampleCountFixed : Int = Math.floor(e.length * _bpm._samplePerTick + exec._decimalFractionSampleCount);
            exec._residueSampleCount = sampleCountFixed >> FIXED_BITS;
            exec._decimalFractionSampleCount = sampleCountFixed & FIXED_FILTER;
        }  // waiting  
        
        
        
        if (exec._residueSampleCount <= _globalBufferSampleCount) {
            _globalExecuteSampleCount = exec._residueSampleCount;
            _globalBufferSampleCount -= _globalExecuteSampleCount;
            exec._residueSampleCount = 0;
            // goto next command
            return e.next;
        }
        else {
            _globalExecuteSampleCount = _globalBufferSampleCount;
            exec._residueSampleCount -= _globalExecuteSampleCount;
            _globalBufferSampleCount = 0;
            // stay on this command
            return e;
        }
    }
    
    
    /** default operation for MMLEvent.PROCESS. */
    private function _default_onProcess(e : MMLEvent) : MMLEvent
    {
        var exec : MMLExecutor = currentExecutor;
        
        // set processing length
        if (exec._residueSampleCount == 0) {
            var sampleCountFixed : Int = Math.floor(e.length * _bpm._samplePerTick + exec._decimalFractionSampleCount);
            exec._residueSampleCount = sampleCountFixed >> FIXED_BITS;
            exec._decimalFractionSampleCount = sampleCountFixed & FIXED_FILTER;
        }

        // processing
        if (exec._residueSampleCount <= _processSampleCount) {
            onProcess(exec._residueSampleCount, e.jump);
            _processSampleCount -= exec._residueSampleCount;
            exec._residueSampleCount = 0;
            // goto next command
            return e.jump.next;
        }
        else {
            onProcess(_processSampleCount, e.jump);
            exec._residueSampleCount -= _processSampleCount;
            _processSampleCount = 0;
            // stay on this command
            return e;
        }
    }
    
    
    /** dummy operation for MMLEvent.PROCESS. */
    private function _dummy_onProcess(e : MMLEvent) : MMLEvent
    {
        var exec : MMLExecutor = currentExecutor;
        
        // set processing length
        if (exec._residueSampleCount == 0) {
            var sampleCountFixed : Int = Math.floor(e.length * _bpm._samplePerTick + exec._decimalFractionSampleCount);
            exec._residueSampleCount = sampleCountFixed >> FIXED_BITS;
            exec._decimalFractionSampleCount = sampleCountFixed & FIXED_FILTER;
        }  // processing  
        
        
        
        if (exec._residueSampleCount <= _processSampleCount) {
            _processSampleCount -= exec._residueSampleCount;
            exec._residueSampleCount = 0;
            // goto next command
            return e.jump.next;
        }
        else {
            exec._residueSampleCount -= _processSampleCount;
            _processSampleCount = 0;
            // stay on this command
            return e;
        }
    }
    
    
    /** default operation for MMLEvent.REPEAT_ALL. */
    private function _default_onRepeatAll(e : MMLEvent) : MMLEvent
    {
        return currentExecutor._onRepeatAll(e);
    }
    
    
    /** default operation for MMLEvent.REPEAT_BEGIN. */
    private function _default_onRepeatBegin(e : MMLEvent) : MMLEvent
    {
        return currentExecutor._onRepeatBegin(e);
    }
    
    
    /** default operation for MMLEvent.REPEAT_BREAK. */
    private function _default_onRepeatBreak(e : MMLEvent) : MMLEvent
    {
        return currentExecutor._onRepeatBreak(e);
    }
    
    
    /** default operation for MMLEvent.REPEAT_END. */
    private function _default_onRepeatEnd(e : MMLEvent) : MMLEvent
    {
        return currentExecutor._onRepeatEnd(e);
    }
    
    
    /** default operation for MMLEvent.SEQUENCE_TAIL. */
    private function _default_onSequenceTail(e : MMLEvent) : MMLEvent
    {
        return currentExecutor._onSequenceTail(e);
    }
    
    
    /** default operation for MMLEvent.TEMPO. */
    private function _default_onTempo(e : MMLEvent) : MMLEvent
    {
        bpm = ((mmlData != null)) ? (mmlData._calcBPMfromTcommand(e.data)) : e.data;
        return e.next;
    }
    
    
    /** default operation for MMLEvent.TIMER. */
    private function _default_onTimer(e : MMLEvent) : MMLEvent
    {
        onTimerInterruption();
        return e.next;
    }
    
    
    /** default operation for MMLEvent.INTERNAL_WAIT. */
    private function _default_onInternalWait(e : MMLEvent) : MMLEvent
    {
        return currentExecutor._publishProessingEvent(e);
    }
    
    
    /** default operation for MMLEvent.INTERNAL_CALL. */
    private function _default_onInternalCall(e : MMLEvent) : MMLEvent
    {
        var callbacks : Array<Dynamic> = currentExecutor.sequence._callbackInternalCall;
        var next : MMLEvent = null;
        if (callbacks[e.data])             next = callbacks[e.data](e.length);
        if (next != null)
            return next;
        else
            return e.next;
    }
}


